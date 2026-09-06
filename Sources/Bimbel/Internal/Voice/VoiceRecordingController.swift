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

/// Hold-mic recorder. Stop the meter *before* `AVAudioRecorder.stop()`.
/// Do not deactivate the audio session on the same turn as `stop()` — that
/// races mediaserverd (process death / SpringBoard) and drops the take.
@MainActor
final class VoiceRecordingController: NSObject, AVAudioRecorderDelegate {
    enum State: Equatable {
        case idle
        case recording
        case locked
        case paused
    }

    private(set) var state: State = .idle
    private var recorder: AVAudioRecorder?
    private var previewPlayer: AVAudioPlayer?
    private var fileURL: URL?
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private var samples: [Float] = []
    /// Main-thread only. `nonisolated(unsafe)` so Swift 6 `deinit` can invalidate.
    private nonisolated(unsafe) var displayLink: CADisplayLink?
    private var pendingTeardown: DispatchWorkItem?
    var onLevel: ((Float, TimeInterval) -> Void)?
    var onStateChange: ((State) -> Void)?

    /// Hold after cancel/send before `stop()` / file delete. Immediate stop+delete
    /// races mediaserverd after the idle UI already landed (SpringBoard).
    static let postVoiceTeardownHold: TimeInterval = 2.2

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
        cancelPendingTeardown(runNow: true)
        stopMeter()
        stopPreview()
        abandonRecorder(deleteFile: true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bimbel-voice-\(UUID().uuidString).m4a")
        fileURL = url
        accumulated = 0
        samples = []
        startedAt = Date()
        state = .recording
        onStateChange?(state)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        startEngine(url: url)
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
        recorder?.pause()
        state = .paused
        onStateChange?(state)
    }

    func resume() {
        guard state == .paused else { return }
        stopPreview()
        startedAt = Date()
        recorder?.record()
        state = .locked
        onStateChange?(state)
    }

    func cancel() {
        stopMeter()
        stopPreview()
        let doomed = fileURL
        fileURL = nil
        samples = []
        accumulated = 0
        state = .idle
        onStateChange?(state)
        scheduleTeardown(delete: doomed)
    }

    /// Hands the temp file to the host. Package does not keep ownership after send.
    func finish() -> VoiceTake? {
        stopMeter()
        let duration = currentDuration
        let waves = samples
        let url = fileURL
        stopPreview()
        fileURL = nil
        samples = []
        accumulated = 0
        state = .idle
        onStateChange?(state)
        // Pause now, `stop()` after `postVoiceTeardownHold`. Immediate `stop()`
        // + session teardown is the post-UI SpringBoard death.
        scheduleTeardown(delete: nil)
        guard let url else { return nil }
        return VoiceTake(url: url, duration: max(duration, 0.2), waveform: waves)
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
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
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
        previewPlayer?.stop()
        previewPlayer = nil
    }

    private func startEngine(url: URL) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            recorder.record()
            self.recorder = recorder
            startMeter()
        } catch {
            startMeter()
        }
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
        recorder?.updateMeters()
        let level = recorder?.averagePower(forChannel: 0) ?? Float.random(in: -40...(-8))
        pushSample(level)
        onLevel?(level, currentDuration)
    }

    private func pushSample(_ value: Float) {
        let normalized: Float
        if value > -1, value < 1.5 {
            normalized = min(1, max(0.08, value))
        } else {
            normalized = min(1, max(0.08, (value + 50) / 50))
        }
        if samples.count >= 48 {
            samples.removeFirst()
        }
        samples.append(normalized)
    }

    private func abandonRecorder(deleteFile: Bool) {
        stopMeter()
        let doomed = deleteFile ? fileURL : nil
        let active = recorder
        recorder = nil
        active?.pause()
        scheduleTeardown(writer: active, delete: doomed)
    }

    private func scheduleTeardown(delete: URL?) {
        let active = recorder
        recorder = nil
        active?.pause()
        scheduleTeardown(writer: active, delete: delete)
    }

    private func scheduleTeardown(writer: AVAudioRecorder?, delete: URL?) {
        pendingTeardown?.cancel()
        nonisolated(unsafe) let writer = writer
        let doomed = delete
        let work = DispatchWorkItem {
            writer?.stop()
            if let doomed {
                try? FileManager.default.removeItem(at: doomed)
            }
            // Leave AVAudioSession active. `setActive(false)` on this path
            // races mediaserverd after the idle UI is already on screen.
        }
        pendingTeardown = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.postVoiceTeardownHold,
            execute: work
        )
    }

    private func cancelPendingTeardown(runNow: Bool) {
        pendingTeardown?.cancel()
        pendingTeardown = nil
        if runNow {
            recorder?.pause()
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        _ = flag
        _ = recorder
    }
}
