import UIKit

struct BubbleCorners: Equatable {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat

    static func zustandB(
        outgoing: Bool,
        decoration: MessageDecoration,
        radii: ConversationTheme.Radii
    ) -> BubbleCorners {
        let full = radii.bubble
        let join = radii.bubbleJoin
        let tail = radii.residualTail

        var corners = BubbleCorners(topLeft: full, topRight: full, bottomLeft: full, bottomRight: full)

        if decoration.mediaStack.isStacked {
            if decoration.mediaStack.joinsTop {
                corners.topLeft = join
                corners.topRight = join
            }
            if decoration.mediaStack.joinsBottom {
                corners.bottomLeft = join
                corners.bottomRight = join
            } else if outgoing {
                corners.bottomRight = tail
            } else {
                corners.bottomLeft = tail
            }
            return corners
        }

        // Consecutive text keeps full rounding (not iMessage collapse). Residual tail only.
        if outgoing {
            corners.bottomRight = decoration.cluster.isLastInCluster ? tail : full
        } else {
            corners.bottomLeft = decoration.cluster.isLastInCluster ? tail : full
        }
        return corners
    }
}

final class BubbleBackgroundView: UIView {
        var corners = BubbleCorners(topLeft: 22, topRight: 22, bottomLeft: 22, bottomRight: 3) {
        didSet {
            setNeedsDisplay()
            setNeedsLayout()
        }
    }
    var fillColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    private let shapeMask = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        layer.mask = shapeMask
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeMask.path = path(in: bounds).cgPath
    }

    override func draw(_ rect: CGRect) {
        fillColor.setFill()
        path(in: bounds).fill()
    }

    func path(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let c = corners
        path.move(to: CGPoint(x: rect.minX + c.topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - c.topRight, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + c.topRight), controlPoint: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c.bottomRight))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - c.bottomRight, y: rect.maxY), controlPoint: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + c.bottomLeft, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - c.bottomLeft), controlPoint: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c.topLeft))
        path.addQuadCurve(to: CGPoint(x: rect.minX + c.topLeft, y: rect.minY), controlPoint: CGPoint(x: rect.minX, y: rect.minY))
        path.close()
        return path
    }
}

final class MetadataOverlay: UIView {
    let timeLabel = UILabel()
    let accessoryView = UIImageView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        layer.cornerRadius = 8
        layer.masksToBounds = true
        timeLabel.font = .systemFont(ofSize: 11, weight: .regular)
        accessoryView.contentMode = .scaleAspectFit
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            accessoryView.widthAnchor.constraint(equalToConstant: 20),
            accessoryView.heightAnchor.constraint(equalToConstant: 12)
        ])
        stack.addArrangedSubview(timeLabel)
        stack.addArrangedSubview(accessoryView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(message: Message, theme: ConversationTheme, onMedia: Bool = false) {
        timeLabel.text = BimbelFormatters.messageTime.string(from: message.sentAt)
        timeLabel.font = theme.fonts.metadata
        if onMedia {
            timeLabel.textColor = .white
            backgroundColor = UIColor.black.withAlphaComponent(0.45)
            stack.layoutMargins = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        } else {
            timeLabel.textColor = theme.colors.metadata
            backgroundColor = .clear
            stack.layoutMargins = .zero
        }
        applyAccessory(message: message, theme: theme)
    }

    func prepareForReuse() {
        accessoryView.isHidden = true
        accessoryView.image = nil
        backgroundColor = .clear
        stack.layoutMargins = .zero
    }

    /// Delivery ticks belong on outgoing bubbles only — including failed.
    private func applyAccessory(message: Message, theme: ConversationTheme) {
        guard message.isOutgoing else {
            accessoryView.isHidden = true
            accessoryView.image = nil
            return
        }
        if message.delivery == .failed {
            accessoryView.image = UIImage(systemName: "exclamationmark.circle.fill")
            accessoryView.tintColor = .systemRed
            accessoryView.isHidden = false
            return
        }
        accessoryView.isHidden = theme.deliveryAccessory == .hidden
        accessoryView.tintColor = message.delivery == .read
            ? theme.colors.accent
            : theme.colors.metadata
        switch theme.deliveryAccessory {
        case .hidden:
            accessoryView.image = nil
        case .dot:
            accessoryView.image = UIImage(systemName: "circle.fill")
        case .ticks:
            accessoryView.image = DeliveryTicks.image(for: message.delivery)
        }
    }
}

final class ReactionChipsView: UIView {
    func configure(reactions: [Reaction], theme: ConversationTheme) {
        arranged.forEach { $0.removeFromSuperview() }
        isHidden = reactions.isEmpty
        for reaction in reactions {
            let chip = UILabel()
            chip.font = theme.fonts.chip
            chip.text = "\(reaction.emoji) \(reaction.userIDs.count)"
            chip.backgroundColor = theme.colors.reactionFill
            chip.layer.cornerRadius = 10
            chip.layer.masksToBounds = true
            chip.textAlignment = .center
            let padded = PaddedLabel()
            padded.text = chip.text
            padded.font = chip.font
            padded.backgroundColor = chip.backgroundColor
            padded.layer.cornerRadius = 10
            padded.layer.masksToBounds = true
            padded.insets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
            stack.addArrangedSubview(padded)
            arranged.append(padded)
        }
    }

    private let stack = UIStackView()
    private var arranged: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .horizontal
        stack.spacing = 4
        addSubview(stack)
        stack.bimbelPinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}

final class LinkPreviewCard: UIView {
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let urlLabel = UILabel()
    private let thumb = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.numberOfLines = 2
        summaryLabel.numberOfLines = 2
        urlLabel.numberOfLines = 1
        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.layer.cornerRadius = 8
        thumb.translatesAutoresizingMaskIntoConstraints = false
        let labels = UIStackView(arrangedSubviews: [titleLabel, summaryLabel, urlLabel])
        labels.axis = .vertical
        labels.spacing = 2
        let row = UIStackView(arrangedSubviews: [labels, thumb])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .top
        addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            thumb.widthAnchor.constraint(equalToConstant: 52),
            thumb.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ preview: LinkPreview, theme: ConversationTheme, outgoing: Bool) {
        titleLabel.font = theme.fonts.linkTitle
        summaryLabel.font = theme.fonts.linkSummary
        urlLabel.font = theme.fonts.metadata
        titleLabel.textColor = theme.colors.linkTitle
        summaryLabel.textColor = outgoing ? theme.colors.outgoingPrimaryText : theme.colors.incomingPrimaryText
        urlLabel.textColor = theme.colors.metadata
        titleLabel.text = preview.title ?? preview.siteName ?? preview.url.host
        summaryLabel.text = preview.summary
        urlLabel.text = preview.url.host
        thumb.isHidden = preview.thumbnail == nil
        if let thumbnail = preview.thumbnail {
            thumb.image = ImageLoader.image(from: thumbnail)
            ImageLoader.load(thumbnail) { [weak self] image in self?.thumb.image = image }
        }
    }
}

final class MediaImageView: UIImageView {
    private var aspect: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = .clear
        aspect = heightAnchor.constraint(equalTo: widthAnchor, multiplier: 1.25)
        aspect.priority = .required
        aspect.isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setAspect(width: Int?, height: Int?) {
        let multiplier: CGFloat
        if let width, let height, width > 0, height > 0 {
            multiplier = min(1.45, max(0.62, CGFloat(height) / CGFloat(width)))
        } else {
            multiplier = 1.25
        }
        aspect.isActive = false
        aspect = heightAnchor.constraint(equalTo: widthAnchor, multiplier: multiplier)
        aspect.priority = .required
        aspect.isActive = true
    }
}
