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

@MainActor
final class VoiceRecordingController {
    enum State: Equatable {
        case idle
        case recording
        case locked
        case paused
    }

    private(set) var state: State = .idle
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    var onLevel: ((Float, TimeInterval) -> Void)?
    var onStateChange: ((State) -> Void)?

    var currentDuration: TimeInterval {
        let running: TimeInterval = (state == .recording || state == .locked) ? Date().timeIntervalSince(startedAt ?? Date()) : 0
        return accumulated + running
    }

    func begin() {
        stopRecorder(keepFile: false)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bimbel-voice-\(UUID().uuidString).m4a")
        fileURL = url
        accumulated = 0
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
        startedAt = Date()
        recorder?.record()
        state = .locked
        onStateChange?(state)
    }

    func cancel() {
        stopRecorder(keepFile: false)
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        fileURL = nil
        state = .idle
        onStateChange?(state)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Hands the temp file to the host. Package does not keep ownership after send.
    func finish() -> URL? {
        let url = fileURL
        stopRecorder(keepFile: true)
        fileURL = nil
        state = .idle
        onStateChange?(state)
        return url
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
            recorder.isMeteringEnabled = true
            recorder.record()
            self.recorder = recorder
            tick()
        } catch {
            // Visual state-machine still runs if the recorder cannot start (simulator / Linux CI).
            tick()
        }
    }

    private func tick() {
        guard state == .recording || state == .locked else { return }
        recorder?.updateMeters()
        let level = recorder?.averagePower(forChannel: 0) ?? Float.random(in: -40...(-8))
        onLevel?(level, currentDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stopRecorder(keepFile: Bool) {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if !keepFile, let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
