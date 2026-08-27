import AVFoundation
import UIKit

enum VoiceGestureOutcome {
    case send
    case cancel
    case lock
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

    func update(translation: CGPoint) -> VoiceGestureOutcome? {
        guard state == .recording else { return nil }
        if translation.x < -80 { return .cancel }
        if translation.y < -80 { return .lock }
        return nil
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
            self?.tick()
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

final class VoiceLockOverlay: UIView {
    var onCancel: (() -> Void)?
    var onLock: (() -> Void)?
    var onPause: (() -> Void)?
    var onSend: (() -> Void)?

    private let waveform = WaveformView()
    private let timeLabel = UILabel()
    private let hintLabel = UILabel()
    private let cancelButton = HitTargetButton(type: .system)
    private let lockButton = HitTargetButton(type: .system)
    private let pauseButton = HitTargetButton(type: .system)
    private let sendButton = HitTargetButton(type: .system)
    private var locked = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.18)
        isHidden = true

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        timeLabel.textColor = .white
        hintLabel.font = .systemFont(ofSize: 13, weight: .medium)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        hintLabel.text = "Slide left to cancel · slide up to lock"

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(tapCancel), for: .touchUpInside)
        cancelButton.accessibilityLabel = "Cancel recording"

        lockButton.setImage(UIImage(systemName: "lock.fill"), for: .normal)
        lockButton.addTarget(self, action: #selector(tapLock), for: .touchUpInside)
        lockButton.accessibilityLabel = "Lock recording"

        pauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        pauseButton.addTarget(self, action: #selector(tapPause), for: .touchUpInside)
        pauseButton.accessibilityLabel = "Pause recording"
        pauseButton.isHidden = true

        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.addTarget(self, action: #selector(tapSend), for: .touchUpInside)
        sendButton.accessibilityLabel = "Send voice message"
        sendButton.isHidden = true

        let column = UIStackView(arrangedSubviews: [lockButton, waveform, timeLabel, hintLabel, cancelButton, pauseButton, sendButton])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = 10
        addSubview(column)
        column.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor),
            waveform.widthAnchor.constraint(equalToConstant: 180),
            waveform.heightAnchor.constraint(equalToConstant: 36)
        ])
        [cancelButton, lockButton, pauseButton, sendButton].forEach {
            $0.tintColor = .white
            $0.setTitleColor(.white, for: .normal)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showRecording() {
        isHidden = false
        locked = false
        pauseButton.isHidden = true
        sendButton.isHidden = true
        lockButton.isHidden = false
        cancelButton.isHidden = false
        hintLabel.isHidden = false
        accessibilityViewIsModal = true
        UIAccessibility.post(notification: .layoutChanged, argument: cancelButton)
    }

    func showLocked() {
        locked = true
        pauseButton.isHidden = false
        sendButton.isHidden = false
        lockButton.isHidden = true
        hintLabel.isHidden = true
        hintLabel.text = "Locked"
        UIAccessibility.post(notification: .layoutChanged, argument: pauseButton)
    }

    func hide() {
        isHidden = true
        waveform.reset()
    }

    func pushLevel(_ level: Float, duration: TimeInterval) {
        waveform.push(level)
        timeLabel.text = BimbelFormatters.duration(duration)
    }

    @objc private func tapCancel() { onCancel?() }
    @objc private func tapLock() { onLock?() }
    @objc private func tapPause() { onPause?() }
    @objc private func tapSend() { onSend?() }
}

final class WaveformView: UIView {
    private var samples: [CGFloat] = Array(repeating: 0.2, count: 32)

    override func draw(_ rect: CGRect) {
        guard let color = tintColor else { return }
        color.setFill()
        let width = bounds.width / CGFloat(samples.count)
        for (index, sample) in samples.enumerated() {
            let height = max(3, sample * bounds.height)
            let bar = CGRect(x: CGFloat(index) * width + 1, y: (bounds.height - height) / 2, width: width - 2, height: height)
            UIBezierPath(roundedRect: bar, cornerRadius: 1.2).fill()
        }
    }

    func push(_ value: Float) {
        let normalized: CGFloat
        if value > -1, value < 1.5 {
            normalized = CGFloat(min(1, max(0.08, value)))
        } else {
            normalized = CGFloat(min(1, max(0.08, (value + 50) / 50)))
        }
        samples.removeFirst()
        samples.append(normalized)
        setNeedsDisplay()
    }

    func reset() {
        samples = Array(repeating: 0.2, count: 32)
        setNeedsDisplay()
    }
}
