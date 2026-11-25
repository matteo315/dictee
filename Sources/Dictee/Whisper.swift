import Foundation

/// Le serveur Whisper local : lancé une fois, il garde le modèle en mémoire pour répondre vite.
final class WhisperServer {
    static let shared = WhisperServer()
    let port = 8178
    private var process: Process?

    private var binary: String? {
        ["/opt/homebrew/bin/whisper-server", "/usr/local/bin/whisper-server"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func start(model: String, language: String, logDir: URL) {
        stop()
        guard let bin = binary else { return }
        // Une copie restée d'un lancement précédent (appli arrêtée sans fermer son serveur) garde 1,6 Go
        // pour rien : plusieurs copies peuvent écouter le même port. On les arrête avant d'en lancer une.
        arreterLesRestes()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["-m", model, "-l", language, "--host", "127.0.0.1", "--port", "\(port)"]
        let logURL = logDir.appendingPathComponent("whisper.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        if let h = try? FileHandle(forWritingTo: logURL) {
            p.standardOutput = h
            p.standardError = h
        }
        do { try p.run(); process = p } catch { process = nil }
    }

    func stop() {
        process?.terminate()
        process = nil
    }

    /// Arrête tout serveur Whisper de Dictée (même port) qui tournerait encore, puis attend qu'il soit parti.
    private func arreterLesRestes() {
        let k = Process()
        k.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        k.arguments = ["-f", "whisper-server .*--port \(port)"]
        try? k.run()
        k.waitUntilExit()
        if k.terminationStatus == 0 { Thread.sleep(forTimeInterval: 0.5) }   // 0 = au moins un reste arrêté
    }

    var isInstalled: Bool { binary != nil }

    func transcribe(wav: Data, language: String, prompt: String) async throws -> String {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/inference")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        let boundary = "dictee-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        field("response_format", "json")
        field("temperature", "0.0")
        field("language", language)
        field("prompt", prompt)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"dictee.wav\"\r\nContent-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wav)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        // Le modèle peut encore se charger juste après l'ouverture : on réessaie quelques secondes.
        var lastError: Error?
        for _ in 0..<40 {
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    struct R: Decodable { let text: String }
                    return try JSONDecoder().decode(R.self, from: data).text
                }
                lastError = NSError(domain: "Dictee", code: 2, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Erreur du serveur"])
            } catch {
                lastError = error
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw lastError ?? NSError(domain: "Dictee", code: 3)
    }
}
