import UIKit

final class InboxRowCell: UITableViewCell {
    static let reuseID = "InboxRowCell"

    private let avatarView = UIImageView()
    private let titleLabel = UILabel()
    private let muteView = UIImageView()
    private let timeLabel = UILabel()
    private let previewLabel = UILabel()
    private let statusView = UIImageView()
    private let unreadDot = UIView()
    private let badgeLabel = PaddedLabel()
    private let titleRow = UIStackView()
    private let trailing = UIStackView()
    private let previewRow = UIStackView()
    private let labels = UIStackView()

    private var avatarLeading: NSLayoutConstraint!
    private var avatarWidth: NSLayoutConstraint!
    private var avatarHeight: NSLayoutConstraint!
    private var labelsLeading: NSLayoutConstraint!
    private var labelsTrailing: NSLayoutConstraint!
    private var labelsTop: NSLayoutConstraint!
    private var labelsBottom: NSLayoutConstraint!
    private var previewHeightConstraint: NSLayoutConstraint!
    private var muteWidth: NSLayoutConstraint!
    private var muteHeight: NSLayoutConstraint!
    private var unreadDotWidth: NSLayoutConstraint!
    private var unreadDotHeight: NSLayoutConstraint!
    private var badgeHeight: NSLayoutConstraint!
    private var rowMinHeight: NSLayoutConstraint!

    private var theme = ConversationTheme.default
    private var item: InboxItem?
    private var hidesTrailingAccessories = false

    /// Exposed for contract tests: the reserved two-line preview height.
    var reservedPreviewHeight: CGFloat {
        previewHeightConstraint.constant
    }

    var showsUnreadPill: Bool { !badgeLabel.isHidden }
    var showsUnreadDot: Bool { !unreadDot.isHidden }
    var showsOutgoingStatus: Bool { !statusView.isHidden }
    var showsMuteGlyph: Bool { !muteView.isHidden }
    var previewAttributedText: NSAttributedString? { previewLabel.attributedText }
    var titleFont: UIFont { titleLabel.font }
    var timeFont: UIFont { timeLabel.font }
    var unreadFont: UIFont? { badgeLabel.font }
    var unreadTextColor: UIColor? { badgeLabel.textColor }
    var muteTint: UIColor? { muteView.tintColor }

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

        badgeLabel.textAlignment = .center
        badgeLabel.layer.masksToBounds = true
        badgeLabel.insets = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)

        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 6
        [titleLabel, muteView, UIView(), timeLabel].forEach { titleRow.addArrangedSubview($0) }

        trailing.axis = .horizontal
        trailing.alignment = .center
        trailing.spacing = 6
        [statusView, unreadDot, badgeLabel].forEach { trailing.addArrangedSubview($0) }

        previewRow.axis = .horizontal
        previewRow.alignment = .top
        previewRow.spacing = theme.layout.inboxTrailingGap
        [previewLabel, trailing].forEach { previewRow.addArrangedSubview($0) }

        labels.axis = .vertical
        labels.spacing = theme.layout.inboxTitlePreviewGap
        labels.translatesAutoresizingMaskIntoConstraints = false
        [titleRow, previewRow].forEach { labels.addArrangedSubview($0) }

        contentView.addSubview(avatarView)
        contentView.addSubview(labels)

        let metrics = theme.layout
        avatarLeading = avatarView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: metrics.inboxHInset
        )
        avatarWidth = avatarView.widthAnchor.constraint(equalToConstant: metrics.inboxAvatar)
        avatarHeight = avatarView.heightAnchor.constraint(equalToConstant: metrics.inboxAvatar)
        labelsLeading = labels.leadingAnchor.constraint(
            equalTo: avatarView.trailingAnchor,
            constant: metrics.inboxAvatarGap
        )
        labelsTrailing = labels.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -metrics.inboxHInset
        )
        let pad = InboxRowMetrics.verticalPadding(theme: theme)
        labelsTop = labels.topAnchor.constraint(equalTo: contentView.topAnchor, constant: pad)
        labelsBottom = labels.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -pad)
        previewHeightConstraint = previewLabel.heightAnchor.constraint(
            equalToConstant: InboxRowMetrics.previewHeight(theme: theme)
        )
        muteWidth = muteView.widthAnchor.constraint(equalToConstant: metrics.inboxMute)
        muteHeight = muteView.heightAnchor.constraint(equalToConstant: metrics.inboxMute)
        unreadDotWidth = unreadDot.widthAnchor.constraint(equalToConstant: metrics.inboxUnreadDot)
        unreadDotHeight = unreadDot.heightAnchor.constraint(equalToConstant: metrics.inboxUnreadDot)
        badgeHeight = badgeLabel.heightAnchor.constraint(equalToConstant: metrics.inboxUnreadPillHeight)
        rowMinHeight = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: metrics.inboxRowMinHeight)

        NSLayoutConstraint.activate([
            avatarLeading, avatarWidth, avatarHeight,
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelsLeading, labelsTrailing, labelsTop, labelsBottom,
            previewHeightConstraint,
            muteWidth, muteHeight,
            statusView.widthAnchor.constraint(equalToConstant: 18),
            statusView.heightAnchor.constraint(equalToConstant: 12),
            unreadDotWidth, unreadDotHeight,
            badgeHeight,
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualTo: badgeLabel.heightAnchor),
            rowMinHeight
        ])
    }

    func configure(item: InboxItem, theme: ConversationTheme, hidesTrailingAccessories: Bool) {
        self.theme = theme
        self.item = item
        self.hidesTrailingAccessories = hidesTrailingAccessories
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        applyMetrics(theme)

        titleLabel.font = theme.fonts.inboxTitle
        titleLabel.textColor = theme.colors.headerTitle
        titleLabel.text = item.title

        let muteSize = theme.layout.inboxMute
        muteView.image = InboxRowMetrics.muteSymbol(size: muteSize)
        muteView.isHidden = !item.isMuted
        muteView.tintColor = theme.colors.inboxMute

        timeLabel.font = theme.fonts.inboxTime
        timeLabel.textColor = theme.colors.metadata
        timeLabel.text = BimbelFormatters.relativeTime(item.timestamp)

        applyPreview(for: item, theme: theme)
        applyUnread(item: item, theme: theme, hidden: hidesTrailingAccessories)
        applyOutgoingStatus(item: item, theme: theme, hidden: hidesTrailingAccessories)

        avatarView.layer.cornerRadius = theme.layout.inboxAvatar / 2
        let fallbackTitle = item.isGroup ? "G" : item.title
        avatarView.image = ImageLoader.image(from: item.avatar)
            ?? InitialGlyph.make(title: fallbackTitle, size: theme.layout.inboxAvatar, colors: theme.colors)
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

    private func applyMetrics(_ theme: ConversationTheme) {
        let layout = theme.layout
        let pad = InboxRowMetrics.verticalPadding(theme: theme)
        avatarLeading.constant = layout.inboxHInset
        avatarWidth.constant = layout.inboxAvatar
        avatarHeight.constant = layout.inboxAvatar
        labelsLeading.constant = layout.inboxAvatarGap
        labelsTrailing.constant = -layout.inboxHInset
        labelsTop.constant = pad
        labelsBottom.constant = -pad
        labels.spacing = layout.inboxTitlePreviewGap
        previewRow.spacing = layout.inboxTrailingGap
        previewHeightConstraint.constant = InboxRowMetrics.previewHeight(theme: theme)
        muteWidth.constant = layout.inboxMute
        muteHeight.constant = layout.inboxMute
        unreadDotWidth.constant = layout.inboxUnreadDot
        unreadDotHeight.constant = layout.inboxUnreadDot
        badgeHeight.constant = layout.inboxUnreadPillHeight
        rowMinHeight.constant = layout.inboxRowMinHeight
    }

    private func applyPreview(for item: InboxItem, theme: ConversationTheme) {
        previewHeightConstraint.constant = InboxRowMetrics.previewHeight(theme: theme)
        previewLabel.attributedText = InboxPreviewResolver.attributedPreview(for: item, theme: theme)
    }

    private func applyUnread(item: InboxItem, theme: ConversationTheme, hidden: Bool) {
        let layout = theme.layout
        unreadDot.backgroundColor = theme.colors.accent
        unreadDot.layer.cornerRadius = layout.inboxUnreadDot / 2
        badgeLabel.font = theme.fonts.inboxUnread
        badgeLabel.textColor = theme.colors.inboxUnreadText
        badgeLabel.backgroundColor = theme.colors.accent
        badgeLabel.layer.cornerRadius = layout.inboxUnreadPillHeight / 2
        badgeLabel.layer.cornerCurve = .continuous

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
