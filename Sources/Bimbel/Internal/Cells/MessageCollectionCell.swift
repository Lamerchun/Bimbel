import UIKit

final class MessageCollectionCell: UICollectionViewCell {
    static let reuseID = "MessageCollectionCell"

    var onReply: ((Message) -> Void)?
    var onOpenURL: ((URL) -> Void)?
    var previewTarget: UIView { bubble }

    private let avatarView = UIImageView()
    private let bubble = BubbleBackgroundView()
    private let textLabel = UILabel()
    private let mediaView = MediaImageView(frame: .zero)
    private let playBadge = UIImageView(image: UIImage(systemName: "play.circle.fill"))
    private let linkCard = LinkPreviewCard()
    private let voiceView = VoiceMessageView()
    private let documentView = DocumentChipView()
    private let metadata = MetadataOverlay()
    private let overlayMetadata = MetadataOverlay()
    private let reactions = ReactionChipsView()
    private let paddedBody = UIStackView()
    private let innerColumn = UIStackView()
    private let bubbleColumn = UIStackView()
    private let hStack = UIStackView()
    private var current: Message?
    private var theme = ConversationTheme.default
    private var swipeOffset: CGFloat = 0
    private var replyTriggered = false
    private var overlayMetadataConstraints: [NSLayoutConstraint] = []
    private var bubbleWidth: NSLayoutConstraint!
    private var leadingAlign: NSLayoutConstraint!
    private var trailingAlign: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false

        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.masksToBounds = true
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        textLabel.numberOfLines = 0
        mediaView.isUserInteractionEnabled = true
        mediaView.layer.masksToBounds = true
        mediaView.layer.cornerRadius = 0

        paddedBody.axis = .vertical
        paddedBody.spacing = 4
        paddedBody.alignment = .fill
        paddedBody.isLayoutMarginsRelativeArrangement = true
        paddedBody.layoutMargins = UIEdgeInsets(top: 8, left: 10, bottom: 6, right: 10)
        [textLabel, linkCard, voiceView, documentView, metadata].forEach { paddedBody.addArrangedSubview($0) }

        innerColumn.axis = .vertical
        innerColumn.spacing = 0
        innerColumn.alignment = .fill
        innerColumn.translatesAutoresizingMaskIntoConstraints = false
        innerColumn.addArrangedSubview(mediaView)
        innerColumn.addArrangedSubview(paddedBody)
        bubble.addSubview(innerColumn)
        NSLayoutConstraint.activate([
            innerColumn.topAnchor.constraint(equalTo: bubble.topAnchor),
            innerColumn.leadingAnchor.constraint(equalTo: bubble.leadingAnchor),
            innerColumn.trailingAnchor.constraint(equalTo: bubble.trailingAnchor),
            innerColumn.bottomAnchor.constraint(equalTo: bubble.bottomAnchor)
        ])

        playBadge.tintColor = .white
        playBadge.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(playBadge)
        NSLayoutConstraint.activate([
            playBadge.centerXAnchor.constraint(equalTo: mediaView.centerXAnchor),
            playBadge.centerYAnchor.constraint(equalTo: mediaView.centerYAnchor),
            playBadge.widthAnchor.constraint(equalToConstant: 44),
            playBadge.heightAnchor.constraint(equalToConstant: 44)
        ])

        overlayMetadata.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(overlayMetadata)
        overlayMetadataConstraints = [
            overlayMetadata.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -8),
            overlayMetadata.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8)
        ]
        NSLayoutConstraint.activate(overlayMetadataConstraints)
        overlayMetadata.isHidden = true

        // Reaction chip sits UNDER the bubble, never on the media corner.
        bubbleColumn.axis = .vertical
        bubbleColumn.spacing = 4
        bubbleColumn.alignment = .fill
        bubbleColumn.addArrangedSubview(bubble)
        bubbleColumn.addArrangedSubview(reactions)

        hStack.axis = .horizontal
        hStack.alignment = .top
        hStack.spacing = 6
        hStack.addArrangedSubview(avatarView)
        hStack.addArrangedSubview(bubbleColumn)
        contentView.addSubview(hStack)
        hStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 28),
            avatarView.heightAnchor.constraint(equalToConstant: 28),
            hStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            hStack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 8),
            hStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),
            hStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        leadingAlign = hStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8)
        trailingAlign = hStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        bubbleWidth = bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.78)
        bubbleWidth.isActive = true

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleReplyPan(_:)))
        pan.delegate = self
        contentView.addGestureRecognizer(pan)

        bubble.isUserInteractionEnabled = true
        linkCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openLink)))
    }

    func configure(
        message: Message,
        decoration: MessageDecoration,
        participant: Participant?,
        theme: ConversationTheme,
        width: CGFloat
    ) {
        current = message
        self.theme = theme
        bubbleWidth.isActive = false
        bubbleWidth = bubble.widthAnchor.constraint(lessThanOrEqualToConstant: max(160, width * theme.layout.bubbleMaxWidthRatio))
        bubbleWidth.isActive = true

        let outgoing = message.isOutgoing
        leadingAlign.isActive = !outgoing
        trailingAlign.isActive = outgoing
        hStack.semanticContentAttribute = outgoing ? .forceRightToLeft : .forceLeftToRight
        bubbleColumn.alignment = outgoing ? .trailing : .leading

        avatarView.isHidden = outgoing || !decoration.reservesIncomingAvatarGutter
        avatarView.alpha = decoration.showsIncomingAvatar ? 1 : 0
        avatarView.layer.cornerRadius = theme.layout.incomingAvatarSize / 2
        if let participant {
            avatarView.image = ImageLoader.image(from: participant.avatar)
                ?? InitialGlyph.make(title: participant.displayName, size: 28, colors: theme.colors)
            if let avatar = participant.avatar {
                ImageLoader.load(avatar) { [weak self] image in
                    if let image { self?.avatarView.image = image }
                }
            }
        } else {
            avatarView.image = InitialGlyph.make(title: "?", size: 28, colors: theme.colors)
        }

        bubble.corners = BubbleCorners.zustandB(outgoing: outgoing, decoration: decoration, radii: theme.radii)
        bubble.fillColor = outgoing ? theme.colors.outgoingBubble : theme.colors.incomingBubble
        bubble.setNeedsDisplay()

        let textColor = outgoing ? theme.colors.outgoingPrimaryText : theme.colors.incomingPrimaryText
        textLabel.font = theme.fonts.body
        textLabel.textColor = textColor
        reactions.configure(reactions: message.reactions, theme: theme)
        reactions.isHidden = message.reactions.isEmpty

        textLabel.isHidden = true
        mediaView.isHidden = true
        linkCard.isHidden = true
        voiceView.isHidden = true
        documentView.isHidden = true
        playBadge.isHidden = true

        switch message.kind {
        case .text(let body, let preview):
            textLabel.isHidden = body.isEmpty
            textLabel.text = body
            if let preview {
                linkCard.isHidden = false
                linkCard.configure(preview, theme: theme, outgoing: outgoing)
            }
        case .image(let media):
            mediaView.isHidden = false
            configureMedia(media)
        case .video(let media):
            mediaView.isHidden = false
            playBadge.isHidden = false
            configureMedia(media)
        case .voice(let voice):
            voiceView.isHidden = false
            voiceView.configure(voice, theme: theme)
        case .document(let document):
            documentView.isHidden = false
            documentView.configure(document, theme: theme, textColor: textColor)
        case .system:
            break
        }

        let mediaVisible = !mediaView.isHidden
        let paddedVisible = !textLabel.isHidden || !linkCard.isHidden || !voiceView.isHidden || !documentView.isHidden
        let mediaOnly = mediaVisible && !paddedVisible
        paddedBody.isHidden = mediaOnly
        overlayMetadata.isHidden = !mediaOnly
        if mediaOnly {
            // Bitmap is the bubble — no incoming/outgoing fill plate around the photo.
            bubble.fillColor = .clear
            bubble.setNeedsDisplay()
            overlayMetadata.configure(message: message, theme: theme, onMedia: true)
        } else {
            metadata.configure(message: message, theme: theme, onMedia: false)
            paddedBody.layoutMargins = UIEdgeInsets(
                top: mediaVisible ? 6 : 8,
                left: 10,
                bottom: 6,
                right: 10
            )
        }
        mediaView.layer.cornerRadius = 0
    }

    private func configureMedia(_ media: Media) {
        mediaView.backgroundColor = .clear
        mediaView.setAspect(width: media.width, height: media.height)
        mediaView.image = ImageLoader.image(from: media.source)
        ImageLoader.load(media.source) { [weak self] image in self?.mediaView.image = image }
    }

    @objc private func handleReplyPan(_ gesture: UIPanGestureRecognizer) {
        guard let message = current, case .system = message.kind else {
            // continue
            performReplyPan(gesture)
            return
        }
    }

    private func performReplyPan(_ gesture: UIPanGestureRecognizer) {
        guard let message = current else { return }
        if case .system = message.kind { return }
        let translation = gesture.translation(in: contentView)
        switch gesture.state {
        case .changed:
            let x = max(0, translation.x)
            hStack.transform = CGAffineTransform(translationX: min(x, 88), y: 0)
            if x > theme.layout.replySwipeThreshold, !replyTriggered {
                replyTriggered = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        case .ended, .cancelled, .failed:
            let shouldReply = replyTriggered
            replyTriggered = false
            UIView.animate(withDuration: 0.22) { self.hStack.transform = .identity }
            if shouldReply { onReply?(message) }
        default:
            break
        }
    }

    @objc private func openLink() {
        if case .text(_, let preview) = current?.kind, let url = preview?.url {
            onOpenURL?(url)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hStack.transform = .identity
        replyTriggered = false
        mediaView.image = nil
        mediaView.backgroundColor = .clear
        metadata.prepareForReuse()
        overlayMetadata.prepareForReuse()
        overlayMetadata.isHidden = true
        paddedBody.isHidden = false
        avatarView.alpha = 1
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let target = CGSize(width: layoutAttributes.frame.width, height: UIView.layoutFittingCompressedSize.height)
        let size = contentView.systemLayoutSizeFitting(
            target,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        attributes.frame.size = CGSize(width: layoutAttributes.frame.width, height: ceil(size.height))
        return attributes
    }
}

extension MessageCollectionCell: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let v = pan.velocity(in: contentView)
        return abs(v.x) > abs(v.y) && v.x > 0
    }
}

final class VoiceMessageView: UIView {
    private let play = UIImageView(image: UIImage(systemName: "play.fill"))
    private let wave = WaveformView()
    private let duration = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        wave.backgroundColor = .clear
        duration.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let stack = UIStackView(arrangedSubviews: [play, wave, duration])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            wave.widthAnchor.constraint(equalToConstant: 96),
            wave.heightAnchor.constraint(equalToConstant: 22),
            play.widthAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ voice: Voice, theme: ConversationTheme) {
        play.tintColor = theme.colors.accent
        wave.tintColor = theme.colors.waveform
        duration.textColor = theme.colors.metadata
        duration.text = BimbelFormatters.duration(voice.duration)
        wave.reset()
        for sample in voice.waveform.prefix(32) {
            wave.push(sample)
        }
    }
}

final class DocumentChipView: UIView {
    private let icon = UIImageView(image: UIImage(systemName: "doc.fill"))
    private let name = UILabel()
    private let size = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        name.font = .systemFont(ofSize: 14, weight: .semibold)
        size.font = .systemFont(ofSize: 12, weight: .regular)
        let labels = UIStackView(arrangedSubviews: [name, size])
        labels.axis = .vertical
        let row = UIStackView(arrangedSubviews: [icon, labels])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            icon.widthAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ document: Document, theme: ConversationTheme, textColor: UIColor) {
        icon.tintColor = theme.colors.accent
        name.textColor = textColor
        size.textColor = theme.colors.metadata
        name.text = document.name
        size.text = ByteCountFormatter.string(fromByteCount: document.byteCount, countStyle: .file)
    }
}
