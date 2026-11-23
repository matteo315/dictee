import Foundation

/// Une dictée terminée et collée.
struct Dictation: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var text: String
    var raw: String
    var words: Int
    var seconds: Double
    var app: String
    var bundleID: String?
}

/// Un nom à bien écrire : la bonne écriture + ce que Whisper entend parfois à la place.
struct DictEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var written: String
    var heard: [String]
}

/// La touche qui pilote la dictée (deux appuis : on parle ; un appui : on colle).
enum Touche: String, Codable, CaseIterable, Identifiable {
    case ctrl, maj, optionDroite, cmdDroite
    var id: String { rawValue }
    var nom: String {
        switch self { case .ctrl: "Ctrl"; case .maj: "Maj"; case .optionDroite: "Option droite"; case .cmdDroite: "Cmd droite" }
    }
    var symbole: String {
        switch self { case .ctrl: "⌃"; case .maj: "⇧"; case .optionDroite: "⌥"; case .cmdDroite: "⌘" }
    }
    /// Codes des touches physiques (gauche et droite quand les deux comptent).
    var keycodes: Set<Int64> {
        switch self { case .ctrl: [59, 62]; case .maj: [56, 60]; case .optionDroite: [61]; case .cmdDroite: [54] }
    }
    /// Bit « enfoncée » dans les modificateurs (bits propres au côté droit pour Option et Cmd).
    var bit: UInt64 {
        switch self { case .ctrl: 0x40000; case .maj: 0x20000; case .optionDroite: 0x40; case .cmdDroite: 0x10 }
    }
}

struct Reglages: Codable {
    var typingWPM: Double = 40
    var language: String = "fr"
    var modelPath: String = ""
    var holdThreshold: Double = 0.4
    var doubleTapWindow: Double = 0.35
    var touche: Touche = .ctrl

    init() {}
    // Lecture tolérante : un réglage ajouté plus tard ne fait pas perdre les autres.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Reglages()
        typingWPM = try c.decodeIfPresent(Double.self, forKey: .typingWPM) ?? d.typingWPM
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? d.language
        modelPath = try c.decodeIfPresent(String.self, forKey: .modelPath) ?? d.modelPath
        holdThreshold = try c.decodeIfPresent(Double.self, forKey: .holdThreshold) ?? d.holdThreshold
        doubleTapWindow = try c.decodeIfPresent(Double.self, forKey: .doubleTapWindow) ?? d.doubleTapWindow
        touche = (try? c.decodeIfPresent(Touche.self, forKey: .touche)) ?? d.touche
    }
}

/// Tout ce que l'appli garde, dans ~/Library/Application Support/Dictee.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var history: [Dictation] = []   // la plus récente en premier
    @Published var dictionary: [DictEntry] = [] { didSet { if loaded { saveDictionary() } } }
    @Published var reglages = Reglages() { didSet { if loaded { saveReglages() } } }

    let dir: URL
    private var loaded = false
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var historyURL: URL { dir.appendingPathComponent("historique.jsonl") }
    private var dictionaryURL: URL { dir.appendingPathComponent("dictionnaire.json") }
    private var reglagesURL: URL { dir.appendingPathComponent("reglages.json") }
    var isFirstLaunch = false

    private init() {
        dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dictee", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
        loaded = true
    }

    private func load() {
        if let data = try? Data(contentsOf: historyURL), let s = String(data: data, encoding: .utf8) {
            history = s.split(separator: "\n").compactMap { try? decoder.decode(Dictation.self, from: Data($0.utf8)) }
                .sorted { $0.date > $1.date }
        }
        if let data = try? Data(contentsOf: dictionaryURL), let d = try? decoder.decode([DictEntry].self, from: data) {
            dictionary = d
        } else {
            isFirstLaunch = true
            dictionary = Store.defaultDictionary
            saveDictionary()
        }
        if let data = try? Data(contentsOf: reglagesURL), let r = try? decoder.decode(Reglages.self, from: data) {
            reglages = r
        } else {
            saveReglages()
        }
    }

    /// Quelques exemples au premier lancement ; chacun ajoute ses propres noms dans l'appli.
    static let defaultDictionary: [DictEntry] = [
        DictEntry(written: "Claude", heard: ["clode"]),
        DictEntry(written: "ChatGPT", heard: ["chat gpt", "tchat gpt"]),
        DictEntry(written: "Wispr Flow", heard: ["whisper flow", "whisperflow"]),
    ]

    func add(_ d: Dictation) {
        history.insert(d, at: 0)
        guard let line = try? encoder.encode(d) else { return }
        var data = line
        data.append(0x0A)
        if let h = try? FileHandle(forWritingTo: historyURL) {
            h.seekToEndOfFile()
            h.write(data)
            try? h.close()
        } else {
            try? data.write(to: historyURL)
        }
    }

    func delete(_ d: Dictation) {
        history.removeAll { $0.id == d.id }
        let lines = history.reversed().compactMap { try? encoder.encode($0) }
        var out = Data()
        for l in lines { out.append(l); out.append(0x0A) }
        try? out.write(to: historyURL)
    }

    private func saveDictionary() {
        if let data = try? encoder.encode(dictionary) { try? data.write(to: dictionaryURL) }
    }

    private func saveReglages() {
        if let data = try? encoder.encode(reglages) { try? data.write(to: reglagesURL) }
    }

    /// Le modèle Whisper : celui des réglages, sinon le premier trouvé.
    var modelPath: String? {
        let candidates = [
            reglages.modelPath,
            dir.appendingPathComponent("ggml-large-v3-turbo.bin").path,
            dir.appendingPathComponent("ggml-large-v3-turbo-q5_0.bin").path,
        ]
        return candidates.first { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }
    }

    /// Le texte donné à Whisper pour l'orienter (ponctuation + noms propres).
    var whisperPrompt: String {
        let noms = dictionary.map(\.written).filter { !$0.isEmpty }.joined(separator: ", ")
        switch reglages.language {
        case "fr": return "Bonjour. Voici une dictée en français, bien ponctuée. Noms : \(noms)."
        case "en": return "Hello. Here is a well-punctuated dictation. Names: \(noms)."
        default: return noms.isEmpty ? "" : "\(noms)."
        }
    }

    // MARK: Statistiques

    struct Stats {
        var totalWords = 0
        var monthWords = 0
        var count = 0
        var wpm = 0
        var savedMinutes: Double = 0
        var streak = 0
        var bestStreak = 0
        var wordsByDay: [Date: Int] = [:]
        var apps: [(name: String, words: Int)] = []
    }

    func stats(now: Date = Date()) -> Stats {
        var s = Stats()
        let cal = Calendar.current
        var seconds: Double = 0
        var byApp: [String: Int] = [:]
        for d in history {
            s.totalWords += d.words
            s.count += 1
            seconds += d.seconds
            if cal.isDate(d.date, equalTo: now, toGranularity: .month) { s.monthWords += d.words }
            s.wordsByDay[cal.startOfDay(for: d.date), default: 0] += d.words
            byApp[d.app.isEmpty ? "Inconnue" : d.app, default: 0] += d.words
        }
        if seconds > 1 { s.wpm = Int((Double(s.totalWords) / (seconds / 60)).rounded()) }
        let typing = Double(s.totalWords) / max(reglages.typingWPM, 1)
        s.savedMinutes = max(0, typing - seconds / 60)
        s.apps = byApp.map { (name: $0.key, words: $0.value) }.sorted { $0.words > $1.words }

        let days = Set(s.wordsByDay.keys)
        var day = cal.startOfDay(for: now)
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        while days.contains(day) {
            s.streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        var best = 0, run = 0
        var prev: Date?
        for d in days.sorted() {
            if let p = prev, cal.date(byAdding: .day, value: 1, to: p) == d { run += 1 } else { run = 1 }
            best = max(best, run)
            prev = d
        }
        s.bestStreak = best
        return s
    }
}
