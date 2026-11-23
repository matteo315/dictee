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
        return true
    }

    private func discard() {
        holdTimer?.cancel()
        _ = recorder.stop()
        mode = .none
        handsFree = false
        phase = .idle
    }

    private func finish() {
        holdTimer?.cancel()
        mode = .none
        handsFree = false
        let samples = recorder.stop()
        let seconds = Double(samples.count) / 16000
        guard seconds >= 0.3, !Recorder.isSilent(samples) else {
            phase = .idle
            return
        }
        phase = .transcribing
        let wav = Recorder.wav(samples)
        let app = targetApp
        let lang = store.reglages.language
        let prompt = store.whisperPrompt
        Task { @MainActor in
            do {
                let raw = try await WhisperServer.shared.transcribe(wav: wav, language: lang, prompt: prompt)
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
