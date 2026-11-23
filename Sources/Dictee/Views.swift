import SwiftUI
import ServiceManagement

// MARK: Charte : fond blanc, filets fins, texte noir, une seule couleur (le noir).

enum Charte {
    static let fond = Color.white
    static let filet = Color.black.opacity(0.09)
    static let texte = Color.black.opacity(0.88)
    static let discret = Color.black.opacity(0.5)
    static let survol = Color.black.opacity(0.035)
}

enum Section: String, CaseIterable, Identifiable {
    case historique = "Historique"
    case stats = "Statistiques"
    case dictionnaire = "Dictionnaire"
    case reglages = "Réglages"
    var id: String { rawValue }
    var icone: String {
        switch self {
        case .historique: return "clock"
        case .stats: return "chart.bar"
        case .dictionnaire: return "character.book.closed"
        case .reglages: return "gearshape"
        }
    }
}

struct MainView: View {
    @State private var section: Section = .historique
    @ObservedObject private var d = Dictator.shared

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform").font(.system(size: 17, weight: .semibold))
                    Text("Dictée").font(.system(size: 19, weight: .semibold))
                }
                .foregroundStyle(Charte.texte)
                .padding(.horizontal, 12)
                .padding(.top, 44)
                .padding(.bottom, 20)

                ForEach(Section.allCases) { s in
                    Button { section = s } label: {
                        HStack(spacing: 10) {
                            Image(systemName: s.icone).frame(width: 18)
                            Text(s.rawValue)
                            Spacer()
                        }
                        .font(.system(size: 14, weight: section == s ? .medium : .regular))
                        .foregroundStyle(Charte.texte)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 8).fill(section == s ? Color.black.opacity(0.06) : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("Double \(Store.shared.reglages.touche.nom) : parler.\n\(Store.shared.reglages.touche.nom) : finir et coller.\nÉchap : annuler.")
                    .font(.system(size: 12))
                    .foregroundStyle(Charte.discret)
                    .lineSpacing(3)
                    .padding(12)
            }
            .frame(width: 210)
            .padding(.horizontal, 10)
            .background(Color(white: 0.975))

            Rectangle().fill(Charte.filet).frame(width: 1)

            VStack(spacing: 0) {
                if let err = d.lastError {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(err).font(.system(size: 13)).foregroundStyle(Charte.texte)
                        Spacer()
                        Button("Fermer") { d.lastError = nil }.buttonStyle(Secondaire())
                    }
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Rectangle().fill(Charte.filet).frame(height: 1) }
                }
                Group {
                    switch section {
                    case .historique: HistoriqueView()
                    case .stats: StatsView()
                    case .dictionnaire: DictionnaireView()
                    case .reglages: ReglagesView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Charte.fond)
        }
        .frame(minWidth: 720, minHeight: 520)
        .ignoresSafeArea()
        .environment(\.colorScheme, .light)
    }
}

struct Titre: View {
    let texte: String
    var body: some View {
        Text(texte)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(Charte.texte)
            .padding(.top, 44)
            .padding(.bottom, 20)
    }
}

/// Champ de saisie : le focus fonce le bord, jamais d'anneau de couleur.
struct Champ: View {
    let placeholder: String
    @Binding var texte: String
    var icone: String? = nil
    @FocusState private var focus: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let icone { Image(systemName: icone).foregroundStyle(Charte.discret) }
            TextField(placeholder, text: $texte)
                .textFieldStyle(.plain)
                .focused($focus)
                .focusEffectDisabled()
        }
        .font(.system(size: 14))
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(focus ? Color.black.opacity(0.55) : Charte.filet.opacity(1.6), lineWidth: 1))
    }
}

struct Secondaire: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Charte.texte)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.black.opacity(0.14), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(Rectangle())
    }
}

struct Principal: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(Rectangle())
    }
}

// MARK: Historique

struct HistoriqueView: View {
    @ObservedObject private var store = Store.shared
    @State private var recherche = ""

    private var filtrees: [Dictation] {
        let q = recherche.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.history }
        return store.history.filter { $0.text.localizedCaseInsensitiveContains(q) || $0.app.localizedCaseInsensitiveContains(q) }
    }

    private var parJour: [(jour: Date, items: [Dictation])] {
        let cal = Calendar.current
        let groupes = Dictionary(grouping: filtrees) { cal.startOfDay(for: $0.date) }
        return groupes.keys.sorted(by: >).map { (jour: $0, items: groupes[$0]!) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Titre(texte: "Historique")
                Spacer()
                Champ(placeholder: "Rechercher", texte: $recherche, icone: "magnifyingglass").frame(width: 240)
            }
            .padding(.horizontal, 32)

            if store.history.isEmpty {
                Text("Aucune dictée pour l'instant. Appuie deux fois sur \(Store.shared.reglages.touche.nom), parle, puis appuie sur \(Store.shared.reglages.touche.nom) : le texte arrive là où est ton curseur.")
                    .font(.system(size: 14)).foregroundStyle(Charte.discret)
                    .padding(.horizontal, 32)
            } else if filtrees.isEmpty {
                Text("Aucune dictée ne contient « \(recherche) ».")
                    .font(.system(size: 14)).foregroundStyle(Charte.discret)
                    .padding(.horizontal, 32)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(parJour, id: \.jour) { groupe in
                            Text(libelleJour(groupe.jour))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Charte.discret)
                                .textCase(.uppercase)
                                .padding(.top, 18).padding(.bottom, 8)
                            VStack(spacing: 0) {
                                ForEach(Array(groupe.items.enumerated()), id: \.element.id) { i, item in
                                    LigneDictee(item: item)
                                    if i < groupe.items.count - 1 { Rectangle().fill(Charte.filet).frame(height: 1) }
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Charte.filet, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private func libelleJour(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Aujourd'hui" }
        if cal.isDateInYesterday(d) { return "Hier" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: d)
    }
}

struct LigneDictee: View {
    let item: Dictation
    @State private var survol = false
    @State private var copie = false

    private static let heure: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(Self.heure.string(from: item.date))
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Charte.discret)
                .frame(width: 42, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.system(size: 14))
                    .foregroundStyle(Charte.texte)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.app.isEmpty {
                    Text("\(item.app) · \(item.words) mots")
                        .font(.system(size: 12))
                        .foregroundStyle(Charte.discret)
                }
            }
            Spacer(minLength: 8)
            Button(copie ? "Copié" : "Copier") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.text, forType: .string)
                copie = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copie = false }
            }
            .buttonStyle(Secondaire())
            .opacity(survol || copie ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(survol ? Charte.survol : .clear)
        .onHover { survol = $0 }
        .contextMenu {
            Button("Copier") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.text, forType: .string)
            }
            Button("Supprimer") { Store.shared.delete(item) }
        }
    }
}

// MARK: Statistiques

struct StatsView: View {
    @ObservedObject private var store = Store.shared

    var body: some View {
        let s = store.stats()
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Titre(texte: "Statistiques")
                if s.count == 0 {
                    Text("Les chiffres apparaîtront après ta première dictée.")
                        .font(.system(size: 14)).foregroundStyle(Charte.discret)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        phrase("\(nombre(s.totalWords)) mots", " dictés, dont \(nombre(s.monthWords)) ce mois-ci.")
                        phrase("\(s.wpm) mots par minute", vitesse(s.wpm))
                        phrase(duree(s.savedMinutes), " gagnées par rapport au clavier (base : \(Int(store.reglages.typingWPM)) mots par minute).")
                        phrase(s.streak <= 1 ? "\(s.streak) jour" : "\(s.streak) jours",
                               " d'affilée. Meilleure série : \(s.bestStreak) jour\(s.bestStreak > 1 ? "s" : "").")
                    }
                    .padding(.bottom, 32)

                    Text("Les 20 dernières semaines")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Charte.texte)
                        .padding(.bottom, 12)
                    GrilleJours(mots: s.wordsByDay)
                        .padding(.bottom, 32)

                    Text("Où tu dictes")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Charte.texte)
                        .padding(.bottom, 12)
                    VStack(spacing: 10) {
                        let max = s.apps.first?.words ?? 1
                        ForEach(s.apps.prefix(8), id: \.name) { a in
                            HStack(spacing: 12) {
                                Text(a.name).font(.system(size: 13)).foregroundStyle(Charte.texte)
                                    .frame(width: 150, alignment: .leading).lineLimit(1)
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.8))
                                        .frame(width: max > 0 ? g.size.width * CGFloat(a.words) / CGFloat(max) : 0, height: 8)
                                        .frame(maxHeight: .infinity, alignment: .center)
                                }
                                .frame(height: 16)
                                Text("\(nombre(a.words)) mots").font(.system(size: 13).monospacedDigit())
                                    .foregroundStyle(Charte.discret).frame(width: 90, alignment: .trailing)
                            }
                        }
                    }
                    .frame(maxWidth: 560)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func phrase(_ fort: String, _ suite: String) -> some View {
        (Text(fort).font(.system(size: 20, weight: .semibold)).foregroundColor(Charte.texte)
         + Text(suite).font(.system(size: 20)).foregroundColor(Charte.texte.opacity(0.7)))
            .monospacedDigit()
    }

    private func vitesse(_ wpm: Int) -> String {
        let r = Double(wpm) / max(store.reglages.typingWPM, 1)
        guard r > 1.05 else { return "." }
        return ", soit \(String(format: "%.1f", r).replacingOccurrences(of: ".", with: ",")) fois plus vite qu'au clavier."
    }

    private func nombre(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func duree(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 60 { return "\(m) min" }
        return "\(m / 60) h \(String(format: "%02d", m % 60))"
    }
}

struct GrilleJours: View {
    let mots: [Date: Int]
    private let semaines = 20

    var body: some View {
        let cal = Calendar(identifier: .iso8601)
        let aujourdhui = cal.startOfDay(for: Date())
        let lundi = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: aujourdhui))!
        let debut = cal.date(byAdding: .weekOfYear, value: -(semaines - 1), to: lundi)!
        let maxi = max(1, mots.values.max() ?? 1)
        let jours = ["Lun", "", "Mer", "", "Ven", "", "Dim"]

        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(0..<7, id: \.self) { j in
                    Text(jours[j]).font(.system(size: 10)).foregroundStyle(Charte.discret).frame(height: 14)
                }
            }
            .padding(.trailing, 4)
            ForEach(0..<semaines, id: \.self) { w in
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { j in
                        let jour = cal.date(byAdding: .day, value: w * 7 + j, to: debut)!
                        let n = mots[jour] ?? 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(jour > aujourdhui ? Color.clear
                                  : n == 0 ? Color.black.opacity(0.05)
                                  : Color.black.opacity(0.25 + 0.65 * Double(n) / Double(maxi)))
                            .frame(width: 14, height: 14)
                            .help(n == 0 ? "" : "\(n) mots")
                    }
                }
            }
        }
    }
}

// MARK: Dictionnaire

struct DictionnaireView: View {
    @ObservedObject private var store = Store.shared
    @State private var nouveau = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Titre(texte: "Dictionnaire").padding(.horizontal, 32)
            Text("Les noms que Dictée doit bien écrire. À droite, ce que Whisper entend parfois à la place, séparé par des virgules.")
                .font(.system(size: 13)).foregroundStyle(Charte.discret)
                .padding(.horizontal, 32).padding(.bottom, 16)

            HStack(spacing: 8) {
                Champ(placeholder: "Nouveau nom, ex. Djamel", texte: $nouveau)
                    .frame(width: 260)
                    .onSubmit(ajouter)
                Button("Ajouter", action: ajouter).buttonStyle(Principal())
                    .disabled(nouveau.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 32).padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text("Écrit").frame(width: 200, alignment: .leading)
                        Text("Entendu comme")
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Charte.discret)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    ForEach($store.dictionary) { $e in
                        Rectangle().fill(Charte.filet).frame(height: 1)
                        LigneDico(entree: $e) {
                            store.dictionary.removeAll { $0.id == e.id }
                        }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Charte.filet, lineWidth: 1))
                .padding(.horizontal, 32).padding(.bottom, 32)
            }
        }
    }

    private func ajouter() {
        let n = nouveau.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        store.dictionary.insert(DictEntry(written: n, heard: []), at: 0)
        nouveau = ""
    }
}

struct LigneDico: View {
    @Binding var entree: DictEntry
    let supprimer: () -> Void
    @State private var entendu = ""

    var body: some View {
        HStack(spacing: 12) {
            Champ(placeholder: "Nom", texte: $entree.written).frame(width: 200)
            Champ(placeholder: "ex. chat gpt, tchat gpt", texte: $entendu)
                .onChange(of: entendu) { _, v in
                    entree.heard = v.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }
            Button("Retirer", action: supprimer).buttonStyle(Secondaire())
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .onAppear { entendu = entree.heard.joined(separator: ", ") }
    }
}

// MARK: Réglages

struct ReglagesView: View {
    @ObservedObject private var store = Store.shared
    @State private var auDemarrage = SMAppService.mainApp.status == .enabled
    @State private var tick = 0
    private let minuteur = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Titre(texte: "Réglages")

                bloc("Raccourcis") {
                    HStack {
                        Text("Touche").font(.system(size: 14))
                        Spacer()
                        Picker("", selection: $store.reglages.touche) {
                            ForEach(Touche.allCases) { t in Text("\(t.nom) \(t.symbole)").tag(t) }
                        }
                        .labelsHidden().frame(width: 220)
                        .onChange(of: store.reglages.touche) { _, t in HotkeyMonitor.touche = t }
                    }
                    ligne("Deux appuis", "commencer à parler")
                    ligne("Un appui", "finir et coller le texte")
                    ligne("Échap", "annuler, rien n'est collé")
                }

                bloc("Autorisations") {
                    let _ = tick
                    autorisation("Micro", Permissions.microphone == .authorized, "Privacy_Microphone")
                    autorisation("Accessibilité (coller le texte, écouter la touche)", Permissions.accessibility, "Privacy_Accessibility")
                    autorisation("Surveillance de la saisie", Permissions.inputMonitoring, "Privacy_ListenEvent")
                }

                bloc("Transcription") {
                    HStack {
                        Text("Langue").font(.system(size: 14))
                        Spacer()
                        Picker("", selection: $store.reglages.language) {
                            Text("Français").tag("fr")
                            Text("Anglais").tag("en")
                            Text("Espagnol").tag("es")
                            Text("Allemand").tag("de")
                            Text("Italien").tag("it")
                            Text("Portugais").tag("pt")
                            Text("Détection automatique").tag("auto")
                        }
                        .labelsHidden().frame(width: 220)
                        .onChange(of: store.reglages.language) { _, _ in redemarrerWhisper() }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("Modèle").font(.system(size: 14))
                        Spacer()
                        Text(store.modelPath.map { ($0 as NSString).lastPathComponent } ?? "aucun modèle trouvé")
                            .font(.system(size: 13)).foregroundStyle(Charte.discret)
                    }
                    HStack {
                        Text("Ta vitesse au clavier").font(.system(size: 14))
                        Spacer()
                        Stepper("\(Int(store.reglages.typingWPM)) mots par minute",
                                 value: $store.reglages.typingWPM, in: 15...120, step: 5)
                            .font(.system(size: 13).monospacedDigit())
                    }
                }

                bloc("Démarrage") {
                    Toggle("Ouvrir Dictée à l'allumage du Mac", isOn: $auDemarrage)
                        .toggleStyle(.switch).tint(.black)
                        .font(.system(size: 14))
                        .onChange(of: auDemarrage) { _, on in
                            do {
                                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            } catch {
                                auDemarrage = SMAppService.mainApp.status == .enabled
                            }
                        }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .onReceive(minuteur) { _ in tick += 1 }
    }

    private func redemarrerWhisper() {
        if let m = store.modelPath {
            WhisperServer.shared.start(model: m, language: store.reglages.language, logDir: store.dir)
        }
    }

    private func bloc<C: View>(_ titre: String, @ViewBuilder _ contenu: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titre).font(.system(size: 13, weight: .semibold)).foregroundStyle(Charte.texte)
            VStack(alignment: .leading, spacing: 12) { contenu() }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Charte.filet, lineWidth: 1))
        }
        .padding(.bottom, 24)
    }

    private func ligne(_ touche: String, _ effet: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(touche).font(.system(size: 14, weight: .medium)).frame(width: 120, alignment: .leading)
            Text(effet).font(.system(size: 14)).foregroundStyle(Charte.texte.opacity(0.75))
        }
    }

    private func autorisation(_ nom: String, _ ok: Bool, _ pane: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(nom).font(.system(size: 14))
            Spacer()
            if ok {
                Text("Autorisé").font(.system(size: 13)).foregroundStyle(Charte.discret)
            } else {
                Button("Autoriser") {
                    if pane == "Privacy_Accessibility" { Permissions.promptAccessibility() }
                    if pane == "Privacy_ListenEvent" { Permissions.requestInputMonitoring() }
                    if pane == "Privacy_Microphone" { Permissions.requestMicrophone() }
                    Permissions.open(pane)
                }
                .buttonStyle(Principal())
            }
        }
    }
}
