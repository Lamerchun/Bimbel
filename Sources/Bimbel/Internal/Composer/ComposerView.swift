import UIKit

/// Signal-iOS `ConversationBottomBar`. The conversation VC pins the bar using
/// this flag — the composer never becomes `inputAccessoryView`.
///
/// Return `true` to have the view controller put this bar above the keyboard
/// (using `keyboardLayoutGuide`). Return `false` to constrain the bottom edge
/// to the bottom of the screen.
protocol ConversationBottomBar: UIView {
    var shouldAttachToKeyboardLayoutGuide: Bool { get }
}

@MainActor
protocol ComposerViewDelegate: AnyObject {
    func composerDidChangeText(_ composer: ComposerView)
    func composerDidTapPlus(_ composer: ComposerView)
    func composerDidLongPressPlus(_ composer: ComposerView)
    func composerDidTapKeyboard(_ composer: ComposerView)
    func composerDidTapSticker(_ composer: ComposerView)
    func composerDidTapCamera(_ composer: ComposerView)
    func composerDidTapSend(_ composer: ComposerView)
    func composerDidBeginMicHold(_ composer: ComposerView)
    func composerDidUpdateMicHold(_ composer: ComposerView, translation: CGPoint)
    func composerDidEndMicHold(_ composer: ComposerView, translation: CGPoint)
    func composerDidCancelReply(_ composer: ComposerView)
    func composerDidChangeHeight(_ composer: ComposerView)
    func composerShouldBeginEditing(_ composer: ComposerView) -> Bool
    func composerDidEndEditing(_ composer: ComposerView)
}

/// Zustand B: floating plus, pill, camera, and mic/send. Not a full-width bar.
final class ComposerView: UIView, UITextViewDelegate {
    weak var delegate: ComposerViewDelegate?

    let plusButton = HitTargetButton(type: .system)
    let pill = UIView()
    /// Capsule fill behind the Message field. iOS 26 `UIView.backgroundColor` draws a square.
    let pillFill = ComposerCapsuleFill()
    let textView = ComposerTextView()
    let stickerButton = HitTargetButton(type: .system)
    let cameraButton = HitTargetButton(type: .system)
    let actionButton = HitTargetButton(type: .system)
    /// Accent Kreis behind mic/send. iOS 26 `UIButton.backgroundColor` fills a square.
    let actionFill = ComposerAccentCircle()
    private let actionHost = UIView()
    let replyBanner = ReplyQuoteView()

    private let stack = UIStackView()
    private let row = UIStackView()
    private var theme = ConversationTheme.default
    private var isSheetPresented = false
    private var hasSendableContent = false
    private var placeholderLabel = UILabel()
    private var textHeightConstraint: NSLayoutConstraint?
    private var suppressPlusTap = false
    private var micHoldOrigin: CGPoint = .zero
    var isDismissPassthroughEnabled = true

    var text: String {
        get { textView.text ?? "" }
        set {
            textView.text = newValue
            textViewDidChange(textView)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        plusButton.addTarget(self, action: #selector(tapPlus), for: .touchUpInside)
        let plusLong = UILongPressGestureRecognizer(target: self, action: #selector(longPlus(_:)))
        plusButton.addGestureRecognizer(plusLong)

        plusButton.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration.bimbelComposerLine), for: .normal)
        plusButton.accessibilityLabel = "Attach"

        stickerButton.setImage(UIImage(systemName: "face.smiling", withConfiguration: UIImage.SymbolConfiguration.bimbelComposerLine), for: .normal)
        stickerButton.addTarget(self, action: #selector(tapSticker), for: .touchUpInside)
        stickerButton.accessibilityLabel = "Stickers"

        cameraButton.setImage(UIImage(systemName: "camera", withConfiguration: UIImage.SymbolConfiguration.bimbelComposerLine), for: .normal)
        cameraButton.addTarget(self, action: #selector(tapCamera), for: .touchUpInside)
        cameraButton.accessibilityLabel = "Camera"

        actionButton.addTarget(self, action: #selector(tapAction), for: .touchUpInside)
        let micHold = UILongPressGestureRecognizer(target: self, action: #selector(holdAction(_:)))
        micHold.minimumPressDuration = 0.12
        // Small allowance so a vertical dismiss pan on the mic does not start a hold.
        // After `.began`, UIKit no longer applies this limit, so slide-to-cancel still works.
        micHold.allowableMovement = 24
        actionButton.addGestureRecognizer(micHold)

        pill.backgroundColor = .clear
        pill.layer.borderWidth = 0
        pill.isExclusiveTouch = false
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.keyboardDismissMode = .none
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        plusButton.isExclusiveTouch = false
        cameraButton.isExclusiveTouch = false
        actionButton.isExclusiveTouch = false

        placeholderLabel.text = "Message"
        placeholderLabel.isUserInteractionEnabled = false

        textHeightConstraint = textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        textHeightConstraint?.isActive = true

        let pillRow = UIStackView(arrangedSubviews: [textView, stickerButton])
        pillRow.axis = .horizontal
        pillRow.alignment = .bottom
        pillRow.spacing = 0
        stickerButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        stickerButton.heightAnchor.constraint(equalToConstant: 44).isActive = true

        pillFill.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(pillFill)
        pill.addSubview(pillRow)
        pill.addSubview(placeholderLabel)
        pillRow.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pillFill.topAnchor.constraint(equalTo: pill.topAnchor),
            pillFill.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            pillFill.trailingAnchor.constraint(equalTo: pill.trailingAnchor),
            pillFill.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
            pillRow.topAnchor.constraint(equalTo: pill.topAnchor),
            pillRow.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            pillRow.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -4),
            pillRow.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 18),
            placeholderLabel.centerYAnchor.constraint(equalTo: pill.centerYAnchor)
        ])

        [plusButton, cameraButton].forEach { button in
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 44),
                button.heightAnchor.constraint(equalToConstant: 44)
            ])
        }

        actionHost.translatesAutoresizingMaskIntoConstraints = false
        actionHost.backgroundColor = .clear
        actionHost.isExclusiveTouch = false
        NSLayoutConstraint.activate([
            actionHost.widthAnchor.constraint(equalToConstant: 44),
            actionHost.heightAnchor.constraint(equalToConstant: 44)
        ])
        actionButton.backgroundColor = .clear
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionFill.translatesAutoresizingMaskIntoConstraints = false
        actionHost.addSubview(actionFill)
        actionHost.addSubview(actionButton)
        NSLayoutConstraint.activate([
            actionFill.widthAnchor.constraint(equalToConstant: 40),
            actionFill.heightAnchor.constraint(equalToConstant: 40),
            actionFill.centerXAnchor.constraint(equalTo: actionHost.centerXAnchor),
            actionFill.centerYAnchor.constraint(equalTo: actionHost.centerYAnchor),
            actionButton.topAnchor.constraint(equalTo: actionHost.topAnchor),
            actionButton.leadingAnchor.constraint(equalTo: actionHost.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: actionHost.trailingAnchor),
            actionButton.bottomAnchor.constraint(equalTo: actionHost.bottomAnchor)
        ])

        row.axis = .horizontal
        row.alignment = .bottom
        row.spacing = 8
        row.addArrangedSubview(plusButton)
        row.addArrangedSubview(pill)
        row.addArrangedSubview(cameraButton)
        row.addArrangedSubview(actionHost)

        replyBanner.isHidden = true
        replyBanner.onClose = { [weak self] in
            guard let self else { return }
            self.delegate?.composerDidCancelReply(self)
        }

        stack.axis = .vertical
        stack.spacing = 6
        stack.addArrangedSubview(replyBanner)
        stack.addArrangedSubview(row)
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        apply(theme: theme, sendable: false, sheetPresented: false)
        installChromeDismissPassthrough()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard superview != nil else { return }
        // Signal `ConversationInputToolbar.didMoveToSuperview`: on iOS 26 the
        // first access of `keyboardLayoutGuide` can report only the home-
        // indicator height (~34). Touch it early so later constraints see the
        // real keyboard.
        if #available(iOS 26, *) {
            _ = keyboardLayoutGuide
        }
    }

    /// Vertical pans on Plus / pill chrome / mic start UIKit's interactive dismiss.
    /// Text selection and an in-progress voice hold are excluded.
    private func installChromeDismissPassthrough() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleChromeDismissPan(_:)))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        addGestureRecognizer(pan)
        plusButton.addGestureRecognizer(passthroughPan())
        cameraButton.addGestureRecognizer(passthroughPan())
        actionButton.addGestureRecognizer(passthroughPan())
        pill.addGestureRecognizer(passthroughPan())
    }

    private func passthroughPan() -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleChromeDismissPan(_:)))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        return pan
    }

    /// Intentionally empty: `keyboardDismissMode = .interactive` owns the keyboard.
    /// The recognizer exists so chrome pans are not eaten by UIButton tracking.
    @objc private func handleChromeDismissPan(_ pan: UIPanGestureRecognizer) {}

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let fitting = CGSize(width: width - 16, height: 0)
        let height = stack.systemLayoutSizeFitting(
            fitting,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        return CGSize(width: UIView.noIntrinsicMetric, height: max(58, height + 10))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        plusButton.layer.cornerRadius = 0
        plusButton.backgroundColor = .clear
        cameraButton.layer.cornerRadius = 0
        cameraButton.backgroundColor = .clear
        // Mic/send fill lives on `actionFill`, not `UIButton.backgroundColor`
        // (iOS 26 paints that as a square). Plus and camera stay glyphs only.
        actionButton.backgroundColor = .clear
        actionButton.layer.cornerRadius = 0
        actionButton.layer.masksToBounds = false
        pill.backgroundColor = .clear
        pill.layer.borderWidth = 0
        delegate?.composerDidChangeHeight(self)
    }

    func apply(theme: ConversationTheme, sendable: Bool, sheetPresented: Bool, reply: Message? = nil) {
        self.theme = theme
        hasSendableContent = sendable
        isSheetPresented = sheetPresented

        plusButton.backgroundColor = .clear
        plusButton.tintColor = theme.colors.composerIcon
        cameraButton.backgroundColor = .clear
        cameraButton.tintColor = theme.colors.composerIcon
        stickerButton.backgroundColor = .clear
        stickerButton.tintColor = theme.colors.composerIcon
        pill.backgroundColor = .clear
        pill.layer.borderWidth = 0
        pill.layer.borderColor = UIColor.clear.cgColor
        pillFill.backgroundColor = theme.colors.composerFill
        textView.textColor = theme.colors.incomingPrimaryText
        textView.font = theme.fonts.body
        textView.tintColor = theme.colors.accent
        placeholderLabel.font = theme.fonts.body
        placeholderLabel.textColor = theme.colors.composerIcon
        stickerButton.tintColor = theme.colors.composerIcon

        let plusName = sheetPresented ? "keyboard" : "plus"
        plusButton.setImage(UIImage(systemName: plusName, withConfiguration: UIImage.SymbolConfiguration.bimbelComposerLine), for: .normal)
        plusButton.accessibilityLabel = sheetPresented ? "Show keyboard" : "Attach"
        plusButton.accessibilityHint = sheetPresented ? nil : "Long press to open the photo library"

        morphAction(sendable: sendable, animated: true)
        cameraButton.isHidden = sendable
        cameraButton.alpha = sendable ? 0 : 1

        if let reply {
            replyBanner.isHidden = false
            replyBanner.configure(message: reply, theme: theme)
        } else {
            replyBanner.isHidden = true
        }
        invalidateIntrinsicContentSize()
    }

    func morphAction(sendable: Bool, animated: Bool) {
        let imageName = sendable ? "paperplane.fill" : "mic.fill"
        let fill = theme.colors.sendFill
        let updates = {
            self.actionButton.setImage(UIImage(systemName: imageName), for: .normal)
            self.actionButton.backgroundColor = .clear
            self.actionFill.backgroundColor = fill
            self.actionButton.tintColor = self.theme.colors.sendIcon
            self.actionButton.accessibilityLabel = sendable ? "Send" : "Record voice message"
        }
        if animated {
            UIView.transition(with: actionHost, duration: 0.22, options: [.transitionCrossDissolve, .curveEaseInOut], animations: updates)
        } else {
            updates()
        }
        hasSendableContent = sendable
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        delegate?.composerShouldBeginEditing(self) ?? true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        delegate?.composerDidEndEditing(self)
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        let fit = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: 120))
        let height = min(max(40, fit.height), 120)
        textView.isScrollEnabled = fit.height > 120
        textHeightConstraint?.constant = height
        invalidateIntrinsicContentSize()
        delegate?.composerDidChangeText(self)
        delegate?.composerDidChangeHeight(self)
    }

    @objc private func tapPlus() {
        if suppressPlusTap {
            suppressPlusTap = false
            return
        }
        if isSheetPresented {
            delegate?.composerDidTapKeyboard(self)
        } else {
            delegate?.composerDidTapPlus(self)
        }
    }

    @objc private func longPlus(_ gesture: UILongPressGestureRecognizer) {
        guard !isSheetPresented, gesture.state == .began else { return }
        suppressPlusTap = true
        delegate?.composerDidLongPressPlus(self)
    }

    @objc private func tapSticker() { delegate?.composerDidTapSticker(self) }
    @objc private func tapCamera() { delegate?.composerDidTapCamera(self) }

    @objc private func tapAction() {
        if hasSendableContent {
            delegate?.composerDidTapSend(self)
        }
    }

    @objc private func holdAction(_ gesture: UILongPressGestureRecognizer) {
        guard !hasSendableContent else { return }
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            micHoldOrigin = location
            delegate?.composerDidBeginMicHold(self)
        case .changed:
            delegate?.composerDidUpdateMicHold(self, translation: micHoldTranslation(to: location))
        default:
            delegate?.composerDidEndMicHold(self, translation: micHoldTranslation(to: location))
        }
    }

    /// Long press has no translation of its own; measure against the touch point taken at `.began`.
    private func micHoldTranslation(to location: CGPoint) -> CGPoint {
        CGPoint(x: location.x - micHoldOrigin.x, y: location.y - micHoldOrigin.y)
    }
}

final class ComposerTextView: UITextView {}

/// Capsule fill for the Message field. Not the pill `backgroundColor` — iOS 26
/// draws that as a rectangle, and `min(composerPill, height/2)` was 0 while height was 0.
final class ComposerCapsuleFill: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityIdentifier = "composer.pill.fill"
        applyCapsule()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyCapsule()
    }

    func applyCapsule() {
        // Never 0. Height 0 happens on the first layout pass; 20 is half of the 40 pt pill.
        let radius = bounds.height > 1 ? bounds.height / 2 : 20
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
    }
}

/// 40 pt accent Kreis for mic/send. Not a `UIButton` background — iOS 26 fills that as a square.
final class ComposerAccentCircle: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.masksToBounds = true
        layer.cornerCurve = .circular
        accessibilityIdentifier = "composer.action.fill"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        layer.cornerRadius = side / 2
        layer.cornerCurve = .circular
        layer.masksToBounds = true
    }
}

extension ComposerView: ConversationBottomBar {
    var shouldAttachToKeyboardLayoutGuide: Bool { true }
}

extension ComposerView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else { return true }
        guard isDismissPassthroughEnabled else { return false }
        if let view = touch.view, view === textView || view.isDescendant(of: textView) {
            return false
        }
        return true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        guard isDismissPassthroughEnabled else { return false }
        let velocity = pan.velocity(in: self)
        return abs(velocity.y) > abs(velocity.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

final class ReplyQuoteView: UIView {
    var onClose: (() -> Void)?
    private let bar = UIView()
    private let titleLabel = UILabel()
    private let previewLabel = UILabel()
    private let closeButton = HitTargetButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 14
        layer.masksToBounds = true
        bar.layer.cornerRadius = 1.5
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        previewLabel.font = .systemFont(ofSize: 13, weight: .regular)
        previewLabel.numberOfLines = 1
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        closeButton.accessibilityLabel = "Cancel reply"

        let labels = UIStackView(arrangedSubviews: [titleLabel, previewLabel])
        labels.axis = .vertical
        labels.spacing = 1

        [bar, labels, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            bar.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            bar.widthAnchor.constraint(equalToConstant: 3),
            labels.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 8),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            labels.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(message: Message, theme: ConversationTheme) {
        backgroundColor = theme.colors.composerFill
        bar.backgroundColor = theme.colors.accent
        titleLabel.textColor = theme.colors.accent
        titleLabel.text = "Reply"
        previewLabel.textColor = theme.colors.headerSubtitle
        previewLabel.text = Self.preview(for: message)
        closeButton.tintColor = theme.colors.composerIcon
    }

    private static func preview(for message: Message) -> String {
        switch message.kind {
        case .text(let body, _): return body
        case .image: return "Photo"
        case .video: return "Video"
        case .voice: return "Voice message"
        case .document(let doc): return doc.name
        case .system(let text): return text
        }
    }

    @objc private func close() { onClose?() }
}

extension UIImage.SymbolConfiguration {
    static let bimbelComposerLine = UIImage.SymbolConfiguration(pointSize: 22, weight: .ultraLight)
}
