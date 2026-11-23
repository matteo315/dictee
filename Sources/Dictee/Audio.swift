import AVFoundation

/// Enregistre le micro en 16 kHz mono (le format de Whisper) et donne le niveau de la voix.
final class Recorder {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private let lock = NSLock()
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    /// Appelé sur le fil principal avec le niveau (0…1) environ 15 fois par seconde.
    var onLevel: ((Float) -> Void)?

    func start() throws {
        lock.lock(); samples.removeAll(keepingCapacity: true); lock.unlock()
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0, fmt.channelCount > 0 else {
            throw NSError(domain: "Dictee", code: 1, userInfo: [NSLocalizedDescriptionKey: "Aucun micro disponible"])
        }
        converter = AVAudioConverter(from: fmt, to: target)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            self?.process(buf)
        }
        engine.prepare()
        try engine.start()
    }

    private func process(_ buf: AVAudioPCMBuffer) {
        guard let conv = converter else { return }
        let ratio = target.sampleRate / buf.format.sampleRate
        let cap = AVAudioFrameCount(Double(buf.frameLength) * ratio + 64)
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: cap) else { return }
        var fed = false
        var err: NSError?
        conv.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buf
        }
        guard let ch = out.floatChannelData, out.frameLength > 0 else { return }
        let n = Int(out.frameLength)
        let ptr = UnsafeBufferPointer(start: ch[0], count: n)
        var sum: Float = 0
        for s in ptr { sum += s * s }
        let rms = sqrt(sum / Float(n))
        lock.lock(); samples.append(contentsOf: ptr); lock.unlock()
        DispatchQueue.main.async { [weak self] in self?.onLevel?(rms) }
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock(); let s = samples; samples = []; lock.unlock()
        return s
    }

    /// Vrai si la voix n'a jamais dépassé un murmure (évite que Whisper invente du texte).
    static func isSilent(_ s: [Float]) -> Bool {
        let win = 1600 // 0,1 s
        var i = 0
        while i + win <= s.count {
            var sum: Float = 0
            for j in i..<(i + win) { sum += s[j] * s[j] }
            if sqrt(sum / Float(win)) > 0.006 { return false }
            i += win
        }
        return true
    }

    /// Fichier WAV 16 bits.
    static func wav(_ s: [Float], rate: Int = 16000) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        let bytes = UInt32(s.count * 2)
        d.append("RIFF".data(using: .ascii)!); u32(36 + bytes)
        d.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(bytes)
        var pcm = [Int16](repeating: 0, count: s.count)
        for (i, v) in s.enumerated() { pcm[i] = Int16(max(-1, min(1, v)) * 32767) }
        pcm.withUnsafeBufferPointer { d.append(Data(buffer: $0)) }
        return d
    }
}
