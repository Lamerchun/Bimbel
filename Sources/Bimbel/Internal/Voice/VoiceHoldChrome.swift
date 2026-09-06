import UIKit

/// Hold-mic HUD glued to the composer (not a centered modal).
/// Recording: live waveform + slide-to-cancel + lock well above the mic.
/// Locked: cancel / pause / send. Hits pass through while the finger is still down.
final class VoiceLockOverlay: UIView {
    var onCancel: (() -> Void)?
    var onLock: (() -> Void)?
    var onPause: (() -> Void)?
    var onSend: (() -> Void)?

    private let holdBar = UIView()
    private let lockedBar = UIView()
    private let holdFill = ComposerCapsuleFill()
    private let lockedFill = ComposerCapsuleFill()
    private let waveform = WaveformView()
    private let lockedWaveform = WaveformView()
    private let timeLabel = UILabel()
    private let lockedTimeLabel = UILabel()
    private let cancelHint = UILabel()
    private let lockWell = HitTargetButton(type: .system)
    private let cancelButton = HitTargetButton(type: .system)
    private let pauseButton = HitTargetButton(type: .system)
    private let sendButton = HitTargetButton(type: .system)
    private var theme = ConversationTheme.default
    private var locked = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        backgroundColor = .clear
        isOpaque = false

        holdBar.backgroundColor = .clear
        lockedBar.backgroundColor = .clear
        lockedBar.isHidden = true

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        lockedTimeLabel.font = timeLabel.font
        cancelHint.font = .systemFont(ofSize: 14, weight: .medium)
        cancelHint.text = String(localized: "Slide to cancel")
        cancelHint.textAlignment = .left

        lockWell.setImage(UIImage.bimbelComposerLine("lock"), for: .normal)
        lockWell.addTarget(self, action: #selector(tapLock), for: .touchUpInside)
        lockWell.accessibilityLabel = String(localized: "Lock recording")
        lockWell.minimumHitSize = CGSize(width: 44, height: 44)

        cancelButton.setImage(UIImage.bimbelComposerLine("trash"), for: .normal)
        cancelButton.addTarget(self, action: #selector(tapCancel), for: .touchUpInside)
        cancelButton.accessibilityLabel = String(localized: "Cancel recording")

        pauseButton.setImage(UIImage.bimbelComposerLine("pause"), for: .normal)
        pauseButton.addTarget(self, action: #selector(tapPause), for: .touchUpInside)
        pauseButton.accessibilityLabel = String(localized: "Pause recording")

        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.addTarget(self, action: #selector(tapSend), for: .touchUpInside)
        sendButton.accessibilityLabel = String(localized: "Send voice message")

        holdBar.addSubview(holdFill)
        holdFill.bimbelPinToEdges(of: holdBar)
        let holdRow = UIStackView(arrangedSubviews: [cancelHint, waveform, timeLabel])
        holdRow.axis = .horizontal
        holdRow.alignment = .center
        holdRow.spacing = 10
        holdBar.addSubview(holdRow)
        holdRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            holdRow.topAnchor.constraint(equalTo: holdBar.topAnchor),
            holdRow.leadingAnchor.constraint(equalTo: holdBar.leadingAnchor, constant: 16),
            holdRow.trailingAnchor.constraint(equalTo: holdBar.trailingAnchor, constant: -60),
            holdRow.bottomAnchor.constraint(equalTo: holdBar.bottomAnchor),
            waveform.widthAnchor.constraint(equalToConstant: 120),
            waveform.heightAnchor.constraint(equalToConstant: 28)
        ])

        lockedBar.addSubview(lockedFill)
        lockedFill.bimbelPinToEdges(of: lockedBar)
        let lockedRow = UIStackView(arrangedSubviews: [cancelButton, lockedWaveform, lockedTimeLabel, pauseButton, sendButton])
        lockedRow.axis = .horizontal
        lockedRow.alignment = .center
        lockedRow.spacing = 10
        lockedBar.addSubview(lockedRow)
        lockedRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lockedRow.topAnchor.constraint(equalTo: lockedBar.topAnchor),
            lockedRow.leadingAnchor.constraint(equalTo: lockedBar.leadingAnchor, constant: 8),
            lockedRow.trailingAnchor.constraint(equalTo: lockedBar.trailingAnchor, constant: -8),
            lockedRow.bottomAnchor.constraint(equalTo: lockedBar.bottomAnchor),
            lockedWaveform.heightAnchor.constraint(equalToConstant: 28),
            cancelButton.widthAnchor.constraint(equalToConstant: 44),
            pauseButton.widthAnchor.constraint(equalToConstant: 44),
            sendButton.widthAnchor.constraint(equalToConstant: 44)
        ])

        [holdBar, lockedBar, lockWell].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            holdBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            holdBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            holdBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            holdBar.heightAnchor.constraint(equalToConstant: 48),
            lockedBar.leadingAnchor.constraint(equalTo: holdBar.leadingAnchor),
            lockedBar.trailingAnchor.constraint(equalTo: holdBar.trailingAnchor),
            lockedBar.bottomAnchor.constraint(equalTo: holdBar.bottomAnchor),
            lockedBar.heightAnchor.constraint(equalTo: holdBar.heightAnchor),
            lockWell.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            lockWell.bottomAnchor.constraint(equalTo: holdBar.topAnchor, constant: -8),
            lockWell.widthAnchor.constraint(equalToConstant: 44),
            lockWell.heightAnchor.constraint(equalToConstant: 44)
        ])
        apply(theme: theme)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit === self { return nil }
        if !locked, hit === holdBar || hit === holdFill || hit === waveform || hit === cancelHint || hit === timeLabel {
            return nil
        }
        return hit
    }

    func apply(theme: ConversationTheme) {
        self.theme = theme
        holdFill.backgroundColor = theme.colors.composerFill
        lockedFill.backgroundColor = theme.colors.composerFill
        waveform.tintColor = theme.colors.waveform
        lockedWaveform.tintColor = theme.colors.waveform
        timeLabel.textColor = theme.colors.incomingPrimaryText
        lockedTimeLabel.textColor = theme.colors.incomingPrimaryText
        cancelHint.textColor = theme.colors.headerSubtitle
        lockWell.tintColor = theme.colors.headerTitle
        lockWell.backgroundColor = theme.colors.composerFill
        lockWell.layer.cornerRadius = 22
        lockWell.layer.masksToBounds = true
        cancelButton.tintColor = .systemRed
        pauseButton.tintColor = theme.colors.headerTitle
        sendButton.tintColor = theme.colors.sendIcon
        sendButton.backgroundColor = theme.colors.sendFill
        sendButton.layer.cornerRadius = 20
        sendButton.layer.masksToBounds = true
    }

    func showRecording() {
        isHidden = false
        locked = false
        holdBar.isHidden = false
        lockedBar.isHidden = true
        lockWell.isHidden = false
        lockWell.alpha = 1
        cancelHint.alpha = 1
        cancelHint.transform = .identity
        cancelHint.text = String(localized: "Slide to cancel")
        lockWell.setImage(UIImage.bimbelComposerLine("lock"), for: .normal)
        accessibilityViewIsModal = false
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Recording. Slide left to cancel, slide up to lock."))
    }

    func showLocked() {
        locked = true
        holdBar.isHidden = true
        lockedBar.isHidden = false
        lockWell.isHidden = true
        pauseButton.setImage(UIImage.bimbelComposerLine("pause"), for: .normal)
        pauseButton.accessibilityLabel = String(localized: "Pause recording")
        accessibilityViewIsModal = true
        UIAccessibility.post(notification: .layoutChanged, argument: pauseButton)
    }

    func hide() {
        isHidden = true
        locked = false
        waveform.reset()
        lockedWaveform.reset()
        cancelHint.transform = .identity
        lockWell.transform = .identity
    }

    func applyHoldProgress(_ translation: CGPoint, cancelAt: CGFloat, lockAt: CGFloat) {
        guard !locked else { return }
        let cancel = min(1, max(0, -translation.x / max(cancelAt, 1)))
        let lock = min(1, max(0, -translation.y / max(lockAt, 1)))
        cancelHint.alpha = 1 - cancel * 0.15
        cancelHint.transform = CGAffineTransform(translationX: min(0, translation.x * 0.35), y: 0)
        cancelHint.textColor = cancel > 0.7 ? .systemRed : theme.colors.headerSubtitle
        lockWell.transform = CGAffineTransform(translationX: 0, y: max(-24, translation.y * 0.2))
            .scaledBy(x: 1 + lock * 0.12, y: 1 + lock * 0.12)
        lockWell.tintColor = lock > 0.7 ? theme.colors.accent : theme.colors.headerTitle
        lockWell.setImage(UIImage.bimbelComposerLine(lock > 0.7 ? "lock.fill" : "lock"), for: .normal)
    }

    func pushLevel(_ level: Float, duration: TimeInterval) {
        waveform.push(level)
        lockedWaveform.push(level)
        let clock = BimbelFormatters.duration(duration)
        timeLabel.text = clock
        lockedTimeLabel.text = clock
    }

    func setPaused(_ paused: Bool) {
        let name = paused ? "play" : "pause"
        pauseButton.setImage(UIImage.bimbelComposerLine(name), for: .normal)
        pauseButton.accessibilityLabel = paused
            ? String(localized: "Resume recording")
            : String(localized: "Pause recording")
    }

    @objc private func tapCancel() { onCancel?() }
    @objc private func tapLock() { onLock?() }
    @objc private func tapPause() { onPause?() }
    @objc private func tapSend() { onSend?() }
}

final class WaveformView: UIView {
    private var samples: [CGFloat] = Array(repeating: 0.2, count: 32)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let color = tintColor else { return }
        color.setFill()
        let width = bounds.width / CGFloat(samples.count)
        for (index, sample) in samples.enumerated() {
            let height = max(3, sample * bounds.height)
            let bar = CGRect(
                x: CGFloat(index) * width + 1,
                y: (bounds.height - height) / 2,
                width: max(1.5, width - 2),
                height: height
            )
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
