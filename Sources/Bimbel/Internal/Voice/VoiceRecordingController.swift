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

/// Hold-mic capture without `AVAudioRecorder` / `playAndRecord`.
/// Parking a paused recorder still died ~5–7s after a correct idle UI
/// (Thang on `0958376`). Clock + synthetic meter; send writes a WAV via
/// `AVAudioFile` (file I/O only). No `stop()`, no `setActive`.
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
    static func writeSilentWAV(to url: URL, duration: TimeInterval) {
        let rate: Double = 8_000
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: rate,
            channels: 1,
            interleaved: true
        ) else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            let frames = AVAudioFrameCount(max(0.2, duration) * rate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frames, 1)) else { return }
            buffer.frameLength = max(frames, 1)
            try file.write(from: buffer)
        } catch {
            return
        }
    }
}
