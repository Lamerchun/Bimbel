import UIKit

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
}

/// Zustand B: floating plus, pill, camera, and mic/send. Not a full-width bar.
final class ComposerView: UIView, UITextViewDelegate {
    weak var delegate: ComposerViewDelegate?

    let plusButton = HitTargetButton(type: .system)
    let pill = UIView()
    let textView = ComposerTextView()
    let stickerButton = HitTargetButton(type: .system)
    let cameraButton = HitTargetButton(type: .system)
    let actionButton = HitTargetButton(type: .system)
    let replyBanner = ReplyQuoteView()

    private let stack = UIStackView()
    private let row = UIStackView()
    private var theme = ConversationTheme.default
    private var isSheetPresented = false
    private var hasSendableContent = false
    private var placeholderLabel = UILabel()
    private var textHeightConstraint: NSLayoutConstraint?
    private var suppressPlusTap = false

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

        stickerButton.setImage(UIImage(systemName: "face.smiling"), for: .normal)
        stickerButton.addTarget(self, action: #selector(tapSticker), for: .touchUpInside)
        stickerButton.accessibilityLabel = "Stickers"

        cameraButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        cameraButton.addTarget(self, action: #selector(tapCamera), for: .touchUpInside)
        cameraButton.accessibilityLabel = "Camera"

        actionButton.addTarget(self, action: #selector(tapAction), for: .touchUpInside)
        let micHold = UILongPressGestureRecognizer(target: self, action: #selector(holdAction(_:)))
        micHold.minimumPressDuration = 0.12
        actionButton.addGestureRecognizer(micHold)

        pill.layer.masksToBounds = true
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.keyboardDismissMode = .interactive
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

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

        pill.addSubview(pillRow)
        pill.addSubview(placeholderLabel)
        pillRow.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pillRow.topAnchor.constraint(equalTo: pill.topAnchor),
            pillRow.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            pillRow.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -4),
            pillRow.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 18),
            placeholderLabel.centerYAnchor.constraint(equalTo: pill.centerYAnchor)
        ])

        [plusButton, cameraButton, actionButton].forEach { button in
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 44),
                button.heightAnchor.constraint(equalToConstant: 44)
            ])
            button.layer.masksToBounds = true
        }

        row.axis = .horizontal
        row.alignment = .bottom
        row.spacing = 8
        row.addArrangedSubview(plusButton)
        row.addArrangedSubview(pill)
        row.addArrangedSubview(cameraButton)
        row.addArrangedSubview(actionButton)

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
    }

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
        plusButton.layer.cornerRadius = plusButton.bounds.height / 2
        cameraButton.layer.cornerRadius = cameraButton.bounds.height / 2
        actionButton.layer.cornerRadius = actionButton.bounds.height / 2
        pill.layer.cornerRadius = min(theme.radii.composerPill, pill.bounds.height / 2)
        delegate?.composerDidChangeHeight(self)
    }

    func apply(theme: ConversationTheme, sendable: Bool, sheetPresented: Bool, reply: Message? = nil) {
        self.theme = theme
        hasSendableContent = sendable
        isSheetPresented = sheetPresented

        plusButton.backgroundColor = theme.colors.plusFill
        plusButton.tintColor = theme.colors.composerIcon
        cameraButton.backgroundColor = theme.colors.plusFill
        cameraButton.tintColor = theme.colors.composerIcon
        pill.backgroundColor = theme.colors.composerFill
        pill.layer.borderWidth = 0.5
        pill.layer.borderColor = theme.colors.composerStroke.cgColor
        textView.textColor = theme.colors.incomingPrimaryText
        textView.font = theme.fonts.body
        textView.tintColor = theme.colors.accent
        placeholderLabel.font = theme.fonts.body
        placeholderLabel.textColor = theme.colors.composerIcon
        stickerButton.tintColor = theme.colors.composerIcon

        let plusName = sheetPresented ? "keyboard" : "plus"
        plusButton.setImage(UIImage(systemName: plusName), for: .normal)
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
        let fill = sendable ? theme.colors.sendFill : theme.colors.sendFill
        let updates = {
            self.actionButton.setImage(UIImage(systemName: imageName), for: .normal)
            self.actionButton.backgroundColor = fill
            self.actionButton.tintColor = self.theme.colors.sendIcon
            self.actionButton.accessibilityLabel = sendable ? "Send" : "Record voice message"
        }
        if animated {
            UIView.transition(with: actionButton, duration: 0.22, options: [.transitionCrossDissolve, .curveEaseInOut], animations: updates)
        } else {
            updates()
        }
        hasSendableContent = sendable
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
        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .began:
            delegate?.composerDidBeginMicHold(self)
        case .changed:
            delegate?.composerDidUpdateMicHold(self, translation: translation)
        default:
            delegate?.composerDidEndMicHold(self, translation: translation)
        }
    }
}

final class ComposerTextView: UITextView {
    /// Zero-height accessory so UIKit treats this field as keyboard-session owner
    /// without drawing IBAV chrome. KeyboardManager still owns vertical position.
    private let dummyAccessory = UIView(frame: .zero)

    override var inputAccessoryView: UIView? {
        get {
            dummyAccessory.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0)
            dummyAccessory.isUserInteractionEnabled = false
            dummyAccessory.backgroundColor = .clear
            return dummyAccessory
        }
        set {}
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
