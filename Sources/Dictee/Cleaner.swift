import Foundation

/// Nettoyage du texte brut de Whisper : hésitations, noms propres, espaces, majuscules.
enum Cleaner {
    /// Phrases que Whisper invente sur un silence (vu sur les vidéos sous-titrées).
    static let hallucinations: [String] = [
        "sous-titres réalisés par la communauté d'amara.org",
        "sous-titres réalisés para la communauté d'amara.org",
        "sous-titres par la communauté d'amara.org",
        "sous-titrage st' 501",
        "sous-titrage société radio-canada",
        "merci d'avoir regardé cette vidéo",
        "merci d'avoir regardé",
        "...",
    ]

    static func clean(_ raw: String, dictionary: [DictEntry]) -> String {
        // Whisper coupe ses lignes au milieu des phrases : on les recolle.
        var t = raw.replacingOccurrences(of: #"\s*\n\s*"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Annotations du type [Musique], (rires), *bruit*
        t = t.replacingOccurrences(of: #"\[[^\]]*\]|\((musique|rires?|applaudissements|bruit)[^)]*\)|\*[^*]*\*"#,
                                   with: "", options: [.regularExpression, .caseInsensitive])

        let norm = t.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        if norm.isEmpty || hallucinations.contains(where: {
            $0.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces)) == norm
        }) {
            return ""
        }

        // Hésitations
        let filler = #"(?i)(?<![\p{L}\p{N}])(bah euh|ben euh|bon euh|euh+|heu+|hum+|hmm+|mmh+)(?![\p{L}\p{N}])[,.…]?\s*"#
        t = t.replacingOccurrences(of: filler, with: "", options: .regularExpression)

        // Noms propres du dictionnaire
        for e in dictionary where !e.written.isEmpty {
            for h in Set(e.heard + [e.written]) where !h.trimmingCharacters(in: .whitespaces).isEmpty {
                let pattern = "(?i)(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: h) + "(?![\\p{L}\\p{N}])"
                t = t.replacingOccurrences(of: pattern,
                                           with: NSRegularExpression.escapedTemplate(for: e.written),
                                           options: .regularExpression)
            }
        }

        // Espaces et virgules orphelines
        t = t.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+([,.…])"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #",\s*([,.?!])"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"^[,.;:\s]+"#, with: "", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)

        return capitalizeSentences(t)
    }

    /// Majuscule en début de texte et après . ? ! …
    static func capitalizeSentences(_ s: String) -> String {
        var out = ""
        var upNext = true
        for ch in s {
            if upNext, ch.isLetter {
                out += ch.uppercased()
                upNext = false
            } else {
                out.append(ch)
                if ".?!…".contains(ch) { upNext = true }
                else if !ch.isWhitespace && !ch.isPunctuation { upNext = false }
            }
        }
        return out
    }

    static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace }).filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }.count
    }
}
