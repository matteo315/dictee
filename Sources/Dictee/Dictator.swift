import AppKit

/// Le chef d'orchestre : touche fn → enregistrement → Whisper → nettoyage → collage → historique.
@MainActor
final class Dictator: ObservableObject {
    static let shared = Dictator()

    enum Phase { case idle, listening, transcribing }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var levels: [CGFloat] = Array(repeating: 0, count: 22)
    @Published private(set) var handsFree = false
    @Published var lastError: String?

    private enum Mode { case none, pending, hold, handsFree }
    private var mode: Mode = .none
    private var lastTapUp = Date.distantPast
    private var ignoreNextUp = false
    private var cancelled = false
    private var targetApp: NSRunningApplication?
    private var holdTimer: DispatchWorkItem?
    private let recorder = Recorder()

    // Transcription par morceaux pendant qu'on parle : à la fin, il ne reste que la dernière phrase à traiter.
    private var minuteurMorceaux: Timer?
    private var coupeA = 0                       // échantillons déjà envoyés à Whisper
    private var morceaux: Task<String, Never>?   // texte brut des morceaux déjà transcrits, dans l'ordre
    private var morceauEchoue = false
    private var seance = 0                       // change à chaque dictée : les résultats d'une dictée annulée sont ignorés
    private static let parSeconde = 16000
    private var store: Store { Store.shared }

    private init() {
        recorder.onLevel = { [weak self] rms in
            MainActor.assumeIsolated { self?.pushLevel(rms) }
        }
    }

    // MARK: Touches

    private var downAt = Date.distantPast
    private var tapSpoiled = false

    /// Ctrl enfoncée. Double Ctrl = on commence ; Ctrl pendant la dictée = on finit.
    /// Un seul appui ne démarre jamais le micro (sinon il s'allumerait à chaque raccourci Ctrl).
    func fnDown() {
        downAt = Date()
        tapSpoiled = false
        switch mode {
        case .handsFree:
            ignoreNextUp = true
            finish()
        case .none:
            guard phase != .transcribing else { return }
            let isDouble = Date().timeIntervalSince(lastTapUp) < store.reglages.doubleTapWindow
            if isDouble {
                lastTapUp = .distantPast
                guard begin() else { return }
                mode = .handsFree
                handsFree = true
                ignoreNextUp = true
                phase = .listening
            }
        default:
            break
        }
    }

    func fnUp() {
        if ignoreNextUp { ignoreNextUp = false; return }
        guard mode == .none else { return }
        // Un appui bref et « propre » (sans autre touche ni clic) compte pour le double appui.
        if !tapSpoiled && Date().timeIntervalSince(downAt) < 0.3 {
            lastTapUp = Date()
        } else {
            lastTapUp = .distantPast
        }
    }

    /// fn + une autre touche (fn+flèche, fn+F1…) : ce n'est pas une dictée.
    func otherKeyWhileFn() {
        tapSpoiled = true
        lastTapUp = .distantPast
    }

    /// Échap : annule l'enregistrement ou la transcription en cours.
    func escape() -> Bool {
        if mode == .hold || mode == .handsFree || phase == .listening {
            discard()
            ignoreNextUp = false
            return true
        }
        if mode == .pending { discard(); return false }
        if phase == .transcribing {
            cancelled = true
            phase = .idle
            return true
        }
        return false
    }

    // MARK: Boutons de la barre

    func startHandsFree() {
        guard mode == .none, phase == .idle, begin() else { return }
        mode = .handsFree
        handsFree = true
        phase = .listening
    }

    func finishFromButton() {
        if mode == .handsFree || mode == .hold { finish() }
    }

    func cancelFromButton() { _ = escape() }

    // MARK: Interne

    private func begin() -> Bool {
        if Permissions.microphone != .authorized {
            Permissions.requestMicrophone()
            lastError = "Autorise le micro pour Dictée dans les Réglages Système."
            return false
        }
        let front = NSWorkspace.shared.frontmostApplication
        targetApp = front?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : front
        cancelled = false
        do {
            try recorder.start()
        } catch {
            lastError = "Le micro n'a pas démarré : \(error.localizedDescription)"
            return false
        }
        levels = Array(repeating: 0, count: levels.count)
        seance += 1
        coupeA = 0
        morceaux = nil
        morceauEchoue = false
        minuteurMorceaux?.invalidate()
        minuteurMorceaux = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.verifierMorceau() }
        }
        return true
    }

    /// Toutes les 0,5 s : après 12 s de parole, on envoie ce qui précède la première pause (ou tout, au-delà de 28 s).
    private func verifierMorceau() {
        guard phase == .listening else { return }
        let n = recorder.sampleCount
        let duree = n - coupeA
        guard duree >= 12 * Dictator.parSeconde else { return }
        let fin = recorder.copy((n - Dictator.parSeconde / 2)..<n)   // la dernière demi-seconde
        if Recorder.isSilent(fin) || duree >= 28 * Dictator.parSeconde {
            let coupe = n - Dictator.parSeconde / 4                    // au milieu de la pause
            envoyerMorceau(recorder.copy(coupeA..<coupe))
            coupeA = coupe
        }
    }

    /// Transcrit un morceau à la suite des précédents (un à la fois, le texte d'avant sert d'amorce).
    private func envoyerMorceau(_ echantillons: [Float]) {
        let precedent = morceaux
        let s = seance
        let lang = store.reglages.language
        let amorce = store.whisperPrompt
        morceaux = Task { @MainActor in
            let avant = await precedent?.value ?? ""
            guard s == self.seance, !Recorder.isSilent(echantillons) else { return avant }
            let prompt = avant.isEmpty ? amorce : amorce + " " + String(avant.suffix(200))
            do {
                let brut = try await WhisperServer.shared.transcribe(wav: Recorder.wav(echantillons), language: lang, prompt: prompt)
                let propre = brut.replacingOccurrences(of: #"\s*\n\s*"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if Cleaner.estInvente(propre) { return avant }
                return avant.isEmpty ? propre : avant + " " + propre
            } catch {
                self.morceauEchoue = true
                return avant
            }
        }
    }

    private func discard() {
        holdTimer?.cancel()
        minuteurMorceaux?.invalidate()
        seance += 1
        morceaux = nil
        _ = recorder.stop()
        mode = .none
        handsFree = false
        phase = .idle
    }

    private func finish() {
        holdTimer?.cancel()
        minuteurMorceaux?.invalidate()
        mode = .none
        handsFree = false
        let samples = recorder.stop()
        let seconds = Double(samples.count) / 16000
        guard seconds >= 0.3, !Recorder.isSilent(samples) else {
            phase = .idle
            return
        }
        phase = .transcribing
        // Le dernier morceau (depuis la dernière coupe) rejoint ceux déjà transcrits pendant la dictée.
        if coupeA < samples.count { envoyerMorceau(Array(samples[coupeA...])) }
        let tache = morceaux
        let app = targetApp
        let lang = store.reglages.language
        let prompt = store.whisperPrompt
        Task { @MainActor in
            do {
                var raw = await tache?.value ?? ""
                // Si un morceau a échoué, on retranscrit toute la dictée d'un coup (comme avant).
                if self.morceauEchoue {
                    raw = try await WhisperServer.shared.transcribe(wav: Recorder.wav(samples), language: lang, prompt: prompt)
                }
                guard !cancelled else { return }
                let text = Cleaner.clean(raw, dictionary: store.dictionary)
                phase = .idle
                guard !text.isEmpty else { return }
                Paster.paste(text)
                store.add(Dictation(date: Date(), text: text, raw: raw,
                                    words: Cleaner.wordCount(text), seconds: seconds,
                                    app: app?.localizedName ?? "", bundleID: app?.bundleIdentifier))
                lastError = nil
            } catch {
                phase = .idle
                lastError = "La transcription a échoué. Whisper est-il installé ? (\(error.localizedDescription))"
            }
        }
    }

    private func pushLevel(_ rms: Float) {
        guard phase == .listening || mode == .pending else { return }
        let v = CGFloat(min(1, sqrt(rms) * 3.2))
        levels.removeFirst()
        levels.append(v)
    }
}
