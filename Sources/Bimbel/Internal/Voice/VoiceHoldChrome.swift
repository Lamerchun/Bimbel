import UIKit

/// Hold-mic HUD glued to the composer (not a centered modal).
/// Recording: live waveform + duration + slide-to-cancel. Lock well above the mic.
/// Locked: Pause · Preview · Send · Discard. Hits pass through while the finger is still down.
final class VoiceLockOverlay: UIView {
    var onCancel: (() -> Void)?
    var onLock: (() -> Void)?
    var onPause: (() -> Void)?
    var onPreview: (() -> Void)?
    var onSend: (() -> Void)?

    private let holdBar = UIView()
    private let lockedBar = UIView()
    private let holdFill = ComposerCapsuleFill()
    private let lockedMaterial = MaterialFactory.makeComposerEffectView(theme: .default)
    private let sendFill = ComposerAccentCircle()
    private let sendHost = UIView()
    private let waveform = WaveformView()
    private let timeLabel = UILabel()
    private let lockedTimeLabel = UILabel()
    private let cancelHint = UILabel()
    private let lockWell = HitTargetButton(type: .system)
    let pauseButton = HitTargetButton(type: .system)
    let previewButton = HitTargetButton(type: .system)
    let sendButton = HitTargetButton(type: .system)
    let discardButton = HitTargetButton(type: .system)
    private var theme = ConversationTheme.default
    private var locked = false
    private var holdHeight: NSLayoutConstraint!
    private var holdLeading: NSLayoutConstraint!
    private var holdTrailing: NSLayoutConstraint!
    private var lockWellTop: NSLayoutConstraint!
    private var waveHeight: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        backgroundColor = .clear
        isOpaque = false

        holdBar.backgroundColor = .clear
        holdBar.accessibilityIdentifier = "voice.recording.bar"
        lockedBar.backgroundColor = .clear
        lockedBar.accessibilityIdentifier = "voice.lock.capsule"
        lockedBar.isHidden = true
        lockedBar.clipsToBounds = true
        lockedBar.layer.cornerCurve = .continuous

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        lockedTimeLabel.font = timeLabel.font
        cancelHint.font = theme.fonts.recordingHint
        cancelHint.text = String(localized: "Slide to cancel")
        cancelHint.textAlignment = .left
        holdFill.layer.borderWidth = 0

        lockWell.setImage(UIImage.bimbelComposerLine("lock"), for: .normal)
        lockWell.addTarget(self, action: #selector(tapLock), for: .touchUpInside)
        lockWell.accessibilityLabel = String(localized: "Lock recording")
        lockWell.minimumHitSize = CGSize(width: 44, height: 44)

        configureLockButton(pauseButton, symbol: "pause", action: #selector(tapPause), label: String(localized: "Pause recording"))
        configureLockButton(previewButton, symbol: "play", action: #selector(tapPreview), label: String(localized: "Preview recording"))
        configureLockButton(discardButton, symbol: "trash", action: #selector(tapCancel), label: String(localized: "Discard recording"))

        sendHost.backgroundColor = .clear
        sendFill.isUserInteractionEnabled = false
        sendButton.setImage(UIImage.bimbelComposerLine("paperplane.fill"), for: .normal)
        sendButton.addTarget(self, action: #selector(tapSend), for: .touchUpInside)
        sendButton.accessibilityLabel = String(localized: "Send voice message")
        sendButton.minimumHitSize = CGSize(width: 44, height: 44)
        sendButton.backgroundColor = .clear
        sendHost.addSubview(sendFill)
        sendHost.addSubview(sendButton)
        sendFill.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sendHost.widthAnchor.constraint(equalToConstant: 44),
            sendHost.heightAnchor.constraint(equalToConstant: 44),
            sendFill.widthAnchor.constraint(equalToConstant: 40),
            sendFill.heightAnchor.constraint(equalToConstant: 40),
            sendFill.centerXAnchor.constraint(equalTo: sendHost.centerXAnchor),
            sendFill.centerYAnchor.constraint(equalTo: sendHost.centerYAnchor),
            sendButton.topAnchor.constraint(equalTo: sendHost.topAnchor),
            sendButton.leadingAnchor.constraint(equalTo: sendHost.leadingAnchor),
            sendButton.trailingAnchor.constraint(equalTo: sendHost.trailingAnchor),
            sendButton.bottomAnchor.constraint(equalTo: sendHost.bottomAnchor)
        ])

        holdBar.addSubview(holdFill)
        holdFill.bimbelPinToEdges(of: holdBar)
        let holdRow = UIStackView(arrangedSubviews: [cancelHint, waveform, timeLabel])
        holdRow.axis = .horizontal
        holdRow.alignment = .center
        holdRow.spacing = 8
        holdBar.addSubview(holdRow)
        holdRow.translatesAutoresizingMaskIntoConstraints = false
        waveHeight = waveform.heightAnchor.constraint(equalToConstant: theme.layout.voiceWaveformHeight)
        NSLayoutConstraint.activate([
            holdRow.topAnchor.constraint(equalTo: holdBar.topAnchor),
            holdRow.leadingAnchor.constraint(equalTo: holdBar.leadingAnchor, constant: 12),
            holdRow.trailingAnchor.constraint(equalTo: holdBar.trailingAnchor, constant: -12),
            holdRow.bottomAnchor.constraint(equalTo: holdBar.bottomAnchor),
            waveform.widthAnchor.constraint(equalToConstant: 96),
            waveHeight
        ])

        lockedMaterial.translatesAutoresizingMaskIntoConstraints = false
        lockedBar.addSubview(lockedMaterial)
        lockedMaterial.bimbelPinToEdges(of: lockedBar)
        let lockedRow = UIStackView(arrangedSubviews: [
            pauseButton, previewButton, lockedTimeLabel, sendHost, discardButton
        ])
        lockedRow.axis = .horizontal
        lockedRow.alignment = .center
        lockedRow.spacing = 8
        lockedRow.distribution = .fill
        lockedBar.addSubview(lockedRow)
        lockedRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lockedRow.topAnchor.constraint(equalTo: lockedBar.topAnchor),
            lockedRow.leadingAnchor.constraint(equalTo: lockedBar.leadingAnchor, constant: 8),
            lockedRow.trailingAnchor.constraint(equalTo: lockedBar.trailingAnchor, constant: -8),
            lockedRow.bottomAnchor.constraint(equalTo: lockedBar.bottomAnchor),
            pauseButton.widthAnchor.constraint(equalToConstant: 44),
            previewButton.widthAnchor.constraint(equalToConstant: 44),
            discardButton.widthAnchor.constraint(equalToConstant: 44)
        ])

        [holdBar, lockedBar, lockWell].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        holdHeight = holdBar.heightAnchor.constraint(equalToConstant: theme.layout.recordingBarHeight)
        holdLeading = holdBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pillLeadingInset)
        holdTrailing = holdBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pillTrailingInset)
        lockWellTop = lockWell.topAnchor.constraint(equalTo: holdBar.topAnchor, constant: -theme.layout.voiceLockZone)
        NSLayoutConstraint.activate([
            holdLeading,
            holdTrailing,
            holdBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            holdHeight,
            lockedBar.leadingAnchor.constraint(equalTo: holdBar.leadingAnchor),
            lockedBar.trailingAnchor.constraint(equalTo: holdBar.trailingAnchor),
            lockedBar.bottomAnchor.constraint(equalTo: holdBar.bottomAnchor),
            lockedBar.heightAnchor.constraint(equalToConstant: 44),
            lockWell.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            lockWellTop,
            lockWell.widthAnchor.constraint(equalToConstant: 44),
            lockWell.heightAnchor.constraint(equalToConstant: 44)
        ])
        apply(theme: theme)
        installVoiceOverActions()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var pillLeadingInset: CGFloat {
        8 + theme.layout.composerControlSize + theme.layout.composerGap
    }

    private var pillTrailingInset: CGFloat {
        8 + theme.layout.composerControlSize + theme.layout.composerGap
            + theme.layout.composerControlSize + theme.layout.composerGap
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = lockedBar.bounds.height > 1
            ? min(theme.radii.lockCapsule, lockedBar.bounds.height / 2)
            : theme.radii.lockCapsule
        lockedBar.layer.cornerRadius = radius
        lockedBar.layer.masksToBounds = true
        lockedMaterial.layer.cornerRadius = radius
        lockedMaterial.clipsToBounds = true
    }

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
        holdFill.layer.borderWidth = 0
        if theme.materials.usesLiquidGlassWhenAvailable, let effect = MaterialFactory.makeLiquidGlassEffect() {
            lockedMaterial.effect = effect
        } else {
            lockedMaterial.effect = UIBlurEffect(style: theme.materials.composer)
        }
        waveform.tintColor = theme.colors.waveform
        waveform.playedTintColor = theme.colors.waveformPlayed
        timeLabel.textColor = theme.colors.headerSubtitle
        lockedTimeLabel.textColor = theme.colors.headerSubtitle
        cancelHint.font = theme.fonts.recordingHint
        cancelHint.textColor = theme.colors.headerSubtitle
        lockWell.tintColor = theme.colors.accent
        lockWell.backgroundColor = theme.colors.composerFill
        lockWell.layer.cornerRadius = theme.radii.lockCapsule
        lockWell.layer.masksToBounds = true
        pauseButton.tintColor = theme.colors.headerTitle
        previewButton.tintColor = theme.colors.headerTitle
        discardButton.tintColor = .systemRed
        sendButton.tintColor = theme.colors.sendIcon
        sendButton.backgroundColor = .clear
        sendFill.backgroundColor = theme.colors.sendFill
        holdHeight?.constant = theme.layout.recordingBarHeight
        holdLeading?.constant = pillLeadingInset
        holdTrailing?.constant = -pillTrailingInset
        lockWellTop?.constant = -theme.layout.voiceLockZone
        waveHeight?.constant = theme.layout.voiceWaveformHeight
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
        cancelHint.textColor = theme.colors.headerSubtitle
        lockWell.tintColor = theme.colors.accent
        lockWell.setImage(UIImage.bimbelComposerLine("lock"), for: .normal)
        accessibilityViewIsModal = false
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Recording. Slide left to cancel, slide up to lock."))
    }

    func showLocked() {
        locked = true
        holdBar.isHidden = true
        lockedBar.isHidden = false
        lockWell.isHidden = true
        installVoiceOverActions()
        accessibilityViewIsModal = true
        isAccessibilityElement = false
        lockedBar.isAccessibilityElement = true
        lockedBar.accessibilityLabel = String(localized: "Locked recording")
        lockedBar.accessibilityHint = String(localized: "Pause, preview, send, or discard.")
        UIAccessibility.post(notification: .layoutChanged, argument: pauseButton)
    }

    func hide() {
        isHidden = true
        locked = false
        waveform.reset()
        cancelHint.transform = .identity
        lockWell.transform = .identity
        lockedBar.isAccessibilityElement = false
    }

    func applyHoldProgress(_ translation: CGPoint, cancelAt: CGFloat, lockAt: CGFloat) {
        guard !locked else { return }
        let cancel = min(1, max(0, -translation.x / max(cancelAt, 1)))
        let lock = min(1, max(0, -translation.y / max(lockAt, 1)))
        cancelHint.alpha = 1 - cancel * 0.15
        cancelHint.transform = CGAffineTransform(translationX: min(0, translation.x * 0.35), y: 0)
        // caption1 secondary → systemRed only after the cancel threshold.
        cancelHint.textColor = cancel >= 1 ? .systemRed : theme.colors.headerSubtitle
        lockWell.transform = CGAffineTransform(translationX: 0, y: max(-24, translation.y * 0.2))
            .scaledBy(x: 1 + lock * 0.12, y: 1 + lock * 0.12)
        lockWell.tintColor = theme.colors.accent
        lockWell.setImage(UIImage.bimbelComposerLine(lock >= 1 ? "lock.fill" : "lock"), for: .normal)
    }

    func pushLevel(_ level: Float, duration: TimeInterval) {
        waveform.push(level)
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
        installVoiceOverActions()
    }

    func setPreviewing(_ playing: Bool) {
        previewButton.setImage(UIImage.bimbelComposerLine(playing ? "stop.fill" : "play"), for: .normal)
        previewButton.accessibilityLabel = playing
            ? String(localized: "Stop preview")
            : String(localized: "Preview recording")
        installVoiceOverActions()
    }

    private func configureLockButton(_ button: HitTargetButton, symbol: String, action: Selector, label: String) {
        button.setImage(UIImage.bimbelComposerLine(symbol), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityLabel = label
        button.minimumHitSize = CGSize(width: 44, height: 44)
    }

    private func installVoiceOverActions() {
        lockedBar.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: pauseButton.accessibilityLabel ?? String(localized: "Pause recording")) { [weak self] _ in
                self?.onPause?()
                return true
            },
            UIAccessibilityCustomAction(name: previewButton.accessibilityLabel ?? String(localized: "Preview recording")) { [weak self] _ in
                self?.onPreview?()
                return true
            },
            UIAccessibilityCustomAction(name: String(localized: "Send voice message")) { [weak self] _ in
                self?.onSend?()
                return true
            },
            UIAccessibilityCustomAction(name: String(localized: "Discard recording")) { [weak self] _ in
                self?.onCancel?()
                return true
            }
        ]
    }

    @objc private func tapCancel() { onCancel?() }
    @objc private func tapLock() { onLock?() }
    @objc private func tapPause() { onPause?() }
    @objc private func tapPreview() { onPreview?() }
    @objc private func tapSend() { onSend?() }
}

final class WaveformView: UIView {
    var playedTintColor: UIColor?
    var progress: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    private var samples: [CGFloat] = Array(repeating: 0.2, count: 32)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let idle = tintColor else { return }
        let played = playedTintColor ?? idle
        let width = bounds.width / CGFloat(samples.count)
        let playedIndex = Int((progress * CGFloat(samples.count)).rounded(.down))
        for (index, sample) in samples.enumerated() {
            (index < playedIndex ? played : idle).setFill()
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

    func setSamples(_ values: [Float]) {
        if values.isEmpty {
            samples = Array(repeating: 0.2, count: 32)
        } else {
            samples = values.prefix(32).map { CGFloat(min(1, max(0.08, $0))) }
            while samples.count < 32 {
                samples.append(0.2)
            }
        }
        setNeedsDisplay()
    }

    func reset() {
        samples = Array(repeating: 0.2, count: 32)
        progress = 0
        setNeedsDisplay()
    }
}
