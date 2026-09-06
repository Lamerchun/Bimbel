import AVFoundation
import UIKit

enum VoiceGestureOutcome: Equatable {
    case send
    case cancel
    case lock
}

enum VoiceGesture {
    /// Horizontal cancel vs vertical lock. The stronger axis wins so a diagonal
    /// hold does not fire both.
    static func outcome(
        translation: CGPoint,
        cancelAt: CGFloat,
        lockAt: CGFloat
    ) -> VoiceGestureOutcome? {
        let left = -translation.x
        let up = -translation.y
        if up >= lockAt, up >= left { return .lock }
        if left >= cancelAt, left >= up { return .cancel }
        return nil
    }
}

/// Hold-mic capture without `AVAudioRecorder` / `playAndRecord` / `setActive`.
/// Clock + synthetic meter. Send writes a hand-rolled silent WAV — not
/// `AVAudioFile.writeFromBuffer`, which traps in ExtAudioFileWrite (CAAssert).
@MainActor
final class VoiceRecordingController: NSObject {
    enum State: Equatable {
        case idle
        case recording
        case locked
        case paused
    }

    private(set) var state: State = .idle
    private var previewPlayer: AVAudioPlayer?
    private var fileURL: URL?
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private var samples: [Float] = []
    /// Main-thread only. `nonisolated(unsafe)` so Swift 6 `deinit` can invalidate.
    private nonisolated(unsafe) var displayLink: CADisplayLink?
    var onLevel: ((Float, TimeInterval) -> Void)?
    var onStateChange: ((State) -> Void)?

    var currentDuration: TimeInterval {
        let running: TimeInterval = (state == .recording || state == .locked) ? Date().timeIntervalSince(startedAt ?? Date()) : 0
        return accumulated + running
    }

    var waveform: [Float] { samples }

    var isPreviewing: Bool { previewPlayer?.isPlaying == true }

    deinit {
        displayLink?.invalidate()
    }

    func begin() {
        stopMeter()
        stopPreview()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bimbel-voice-\(UUID().uuidString).wav")
        accumulated = 0
        samples = []
        startedAt = Date()
        state = .recording
        onStateChange?(state)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        startMeter()
    }

    func update(translation: CGPoint, cancelAt: CGFloat, lockAt: CGFloat) -> VoiceGestureOutcome? {
        guard state == .recording else { return nil }
        return VoiceGesture.outcome(translation: translation, cancelAt: cancelAt, lockAt: lockAt)
    }

    func lock() {
        guard state == .recording else { return }
        state = .locked
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onStateChange?(state)
    }

    func pause() {
        guard state == .locked || state == .recording else { return }
        if let startedAt {
            accumulated += Date().timeIntervalSince(startedAt)
        }
        startedAt = nil
        state = .paused
        onStateChange?(state)
    }

    func resume() {
        guard state == .paused else { return }
        stopPreview()
        startedAt = Date()
        state = .locked
        onStateChange?(state)
    }

    func cancel() {
        stopMeter()
        stopPreview()
        fileURL = nil
        samples = []
        accumulated = 0
        state = .idle
        onStateChange?(state)
    }

    func finish() -> VoiceTake? {
        stopMeter()
        let duration = max(currentDuration, 0.2)
        let waves = samples
        let url = fileURL
        stopPreview()
        fileURL = nil
        samples = []
        accumulated = 0
        state = .idle
        onStateChange?(state)
        guard let url else { return nil }
        VoiceTakeWriter.writeSilentWAV(to: url, duration: duration)
        return VoiceTake(url: url, duration: duration, waveform: waves)
    }

    @discardableResult
    func togglePreview() -> Bool {
        if previewPlayer?.isPlaying == true {
            previewPlayer?.pause()
            return false
        }
        if state == .locked || state == .recording {
            pause()
        }
        guard let fileURL else { return false }
        VoiceTakeWriter.writeSilentWAV(to: fileURL, duration: max(currentDuration, 0.2))
        do {
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.enableRate = true
            player.rate = 1
            player.play()
            previewPlayer = player
            return true
        } catch {
            return false
        }
    }

    func stopPreview() {
        previewPlayer?.pause()
        previewPlayer = nil
    }

    private func startMeter() {
        stopMeter()
        let link = CADisplayLink(target: self, selector: #selector(pulseMeter))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 20, preferred: 15)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopMeter() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func pulseMeter() {
        guard state == .recording || state == .locked else { return }
        let level = Float.random(in: -40...(-8))
        pushSample(level)
        onLevel?(level, currentDuration)
    }

    private func pushSample(_ value: Float) {
        let normalized = min(1, max(0.08, (value + 50) / 50))
        if samples.count >= 48 {
            samples.removeFirst()
        }
        samples.append(normalized)
    }
}

enum VoiceTakeWriter {
    /// PCM16 LE mono 8 kHz RIFF. Bytes only — AudioToolbox `ExtAudioFileWrite`
    /// / `AudioConverterFillComplexBuffer` aborted on `AVAudioFile` + Int16
    /// buffer (empty converter input, CAVerboseAbort).
    static func writeSilentWAV(to url: URL, duration: TimeInterval) {
        let sampleRate = 8_000
        // Placeholder payload, not the hold length. Keep the file tiny.
        let seconds = 0.25
        _ = duration
        let frames = Int((seconds * Double(sampleRate)).rounded())
        let dataBytes = max(frames, 1) * 2
        var data = Data()
        data.reserveCapacity(44 + dataBytes)
        func fourCC(_ ascii: String) {
            data.append(contentsOf: ascii.utf8)
        }
        func u16(_ value: UInt16) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func u32(_ value: UInt32) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        fourCC("RIFF")
        u32(UInt32(36 + dataBytes))
        fourCC("WAVE")
        fourCC("fmt ")
        u32(16)
        u16(1)
        u16(1)
        u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * 2))
        u16(2)
        u16(16)
        fourCC("data")
        u32(UInt32(dataBytes))
        data.append(Data(count: dataBytes))
        try? data.write(to: url, options: .atomic)
    }
}
