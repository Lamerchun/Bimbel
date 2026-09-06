import UIKit

final class InboxRowCell: UITableViewCell {
    static let reuseID = "InboxRowCell"

    private let avatarView = UIImageView()
    private let titleLabel = UILabel()
    private let muteView = UIImageView(image: UIImage(systemName: "speaker.slash.fill"))
    private let timeLabel = UILabel()
    private let previewLabel = UILabel()
    private let statusView = UIImageView()
    private let unreadDot = UIView()
    private let badgeLabel = PaddedLabel()
    private var previewHeightConstraint: NSLayoutConstraint?
    private var theme = ConversationTheme.default
    private var item: InboxItem?
    private var hidesTrailingAccessories = false

    /// Exposed for contract tests: the reserved two-line preview height.
    var reservedPreviewHeight: CGFloat {
        previewHeightConstraint?.constant ?? 0
    }

    var showsUnreadPill: Bool { !badgeLabel.isHidden }
    var showsUnreadDot: Bool { !unreadDot.isHidden }
    var showsOutgoingStatus: Bool { !statusView.isHidden }
    var showsMuteGlyph: Bool { !muteView.isHidden }
    var previewAttributedText: NSAttributedString? { previewLabel.attributedText }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .default

        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.masksToBounds = true
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        muteView.contentMode = .scaleAspectFit
        muteView.setContentHuggingPriority(.required, for: .horizontal)
        muteView.setContentCompressionResistancePriority(.required, for: .horizontal)

        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        previewLabel.numberOfLines = InboxRowMetrics.previewLines
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        previewLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        statusView.contentMode = .scaleAspectFit
        statusView.setContentHuggingPriority(.required, for: .horizontal)

        unreadDot.layer.masksToBounds = true
        unreadDot.translatesAutoresizingMaskIntoConstraints = false

        badgeLabel.textAlignment = .center
        badgeLabel.layer.masksToBounds = true
        badgeLabel.insets = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, muteView, UIView(), timeLabel])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 6

        let trailing = UIStackView(arrangedSubviews: [statusView, unreadDot, badgeLabel])
        trailing.axis = .horizontal
        trailing.alignment = .center
        trailing.spacing = 6

        let previewRow = UIStackView(arrangedSubviews: [previewLabel, trailing])
        previewRow.axis = .horizontal
        previewRow.alignment = .top
        previewRow.spacing = 8

        let labels = UIStackView(arrangedSubviews: [titleRow, previewRow])
        labels.axis = .vertical
        labels.spacing = 4
        labels.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(avatarView)
        contentView.addSubview(labels)

        let previewHeight = previewLabel.heightAnchor.constraint(
            equalToConstant: InboxRowMetrics.previewHeight(theme: theme)
        )
        previewHeightConstraint = previewHeight

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: InboxRowMetrics.horizontalInset
            ),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: InboxRowMetrics.avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: InboxRowMetrics.avatarSize),
            avatarView.topAnchor.constraint(
                greaterThanOrEqualTo: contentView.topAnchor,
                constant: InboxRowMetrics.verticalPadding
            ),

            labels.leadingAnchor.constraint(
                equalTo: avatarView.trailingAnchor,
                constant: InboxRowMetrics.avatarTextGap
            ),
            labels.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -InboxRowMetrics.horizontalInset
            ),
            labels.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: InboxRowMetrics.verticalPadding
            ),
            labels.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -InboxRowMetrics.verticalPadding
            ),

            previewHeight,
            muteView.widthAnchor.constraint(equalToConstant: 14),
            muteView.heightAnchor.constraint(equalToConstant: 14),
            statusView.widthAnchor.constraint(equalToConstant: 18),
            statusView.heightAnchor.constraint(equalToConstant: 12),
            unreadDot.widthAnchor.constraint(equalToConstant: InboxRowMetrics.unreadDotSize),
            unreadDot.heightAnchor.constraint(equalToConstant: InboxRowMetrics.unreadDotSize),
            badgeLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20)
        ])
    }

    func configure(item: InboxItem, theme: ConversationTheme, hidesTrailingAccessories: Bool) {
        self.theme = theme
        self.item = item
        self.hidesTrailingAccessories = hidesTrailingAccessories
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        let unread = item.showsUnread
        titleLabel.font = unread
            ? .systemFont(ofSize: 16, weight: .semibold)
            : .systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = theme.colors.headerTitle
        titleLabel.text = item.title

        muteView.isHidden = !item.isMuted
        muteView.tintColor = theme.colors.metadata

        timeLabel.font = theme.fonts.metadata
        timeLabel.textColor = unread && !hidesTrailingAccessories
            ? theme.colors.accent
            : theme.colors.metadata
        timeLabel.text = BimbelFormatters.relativeTime(item.timestamp)

        applyPreview(for: item, theme: theme)

        let hideChrome = hidesTrailingAccessories
        applyUnread(item: item, theme: theme, hidden: hideChrome)
        applyOutgoingStatus(item: item, theme: theme, hidden: hideChrome)

        avatarView.layer.cornerRadius = InboxRowMetrics.avatarSize / 2
        let fallbackTitle = item.isGroup ? "G" : item.title
        avatarView.image = ImageLoader.image(from: item.avatar)
            ?? InitialGlyph.make(title: fallbackTitle, size: InboxRowMetrics.avatarSize, colors: theme.colors)
        if let avatar = item.avatar {
            ImageLoader.load(avatar) { [weak self] image in
                if let image { self?.avatarView.image = image }
            }
        }

        accessibilityLabel = accessibility(for: item)
    }

    /// Typing can replace the preview string without dequeuing a new cell.
    func applyTyping(_ isTyping: Bool) {
        guard var item else { return }
        item.isTyping = isTyping
        self.item = item
        applyPreview(for: item, theme: theme)
        applyOutgoingStatus(item: item, theme: theme, hidden: hidesTrailingAccessories)
        accessibilityLabel = accessibility(for: item)
    }

    private func applyPreview(for item: InboxItem, theme: ConversationTheme) {
        let font = InboxRowMetrics.previewFont(theme: theme)
        previewHeightConstraint?.constant = InboxRowMetrics.previewHeight(font: font)
        previewLabel.attributedText = InboxPreviewResolver.attributedPreview(for: item, theme: theme)
    }

    private func applyUnread(item: InboxItem, theme: ConversationTheme, hidden: Bool) {
        unreadDot.backgroundColor = theme.colors.accent
        unreadDot.layer.cornerRadius = InboxRowMetrics.unreadDotSize / 2
        badgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        badgeLabel.textColor = theme.colors.badgeText
        badgeLabel.backgroundColor = theme.colors.accent
        badgeLabel.layer.cornerRadius = 10

        if hidden || !item.showsUnread {
            badgeLabel.isHidden = true
            unreadDot.isHidden = true
            return
        }
        if let text = BimbelFormatters.badgeText(item.unreadCount) {
            badgeLabel.isHidden = false
            badgeLabel.text = text
            unreadDot.isHidden = true
        } else {
            badgeLabel.isHidden = true
            unreadDot.isHidden = false
        }
    }

    private func applyOutgoingStatus(item: InboxItem, theme: ConversationTheme, hidden: Bool) {
        guard !hidden,
              InboxPreviewResolver.showsOutgoingStatus(for: item),
              let delivery = item.lastOutgoingDelivery
        else {
            statusView.isHidden = true
            return
        }
        statusView.isHidden = false
        statusView.image = DeliveryTicks.image(for: delivery)
        statusView.tintColor = delivery == .read ? theme.colors.accent : theme.colors.metadata
    }

    private func accessibility(for item: InboxItem) -> String {
        var parts = [item.title]
        parts.append(InboxPreviewResolver.accessibilityPreview(for: item))
        if item.unreadCount > 0 {
            parts.append("\(item.unreadCount)")
        } else if item.markedUnread {
            parts.append(String(localized: "Unread"))
        }
        if item.isPinned { parts.append(String(localized: "Pinned")) }
        if item.isMuted { parts.append(String(localized: "Muted")) }
        return parts.joined(separator: ", ")
    }
}
