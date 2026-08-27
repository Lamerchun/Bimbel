import UIKit

final class InboxRowCell: UITableViewCell {
    static let reuseID = "InboxRowCell"

    private let avatarView = UIImageView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let previewLabel = UILabel()
    private let pinView = UIImageView(image: UIImage(systemName: "pin.fill"))
    private let muteView = UIImageView(image: UIImage(systemName: "speaker.slash.fill"))
    private let badgeLabel = PaddedLabel()
    private var theme = ConversationTheme.default

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

        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        previewLabel.numberOfLines = 1
        previewLabel.lineBreakMode = .byTruncatingTail

        pinView.contentMode = .scaleAspectFit
        muteView.contentMode = .scaleAspectFit
        badgeLabel.textAlignment = .center
        badgeLabel.layer.masksToBounds = true
        badgeLabel.insets = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)

        let top = UIStackView(arrangedSubviews: [titleLabel, timeLabel])
        top.axis = .horizontal
        top.alignment = .firstBaseline
        top.spacing = 8

        let bottom = UIStackView(arrangedSubviews: [previewLabel, pinView, muteView, badgeLabel])
        bottom.axis = .horizontal
        bottom.alignment = .center
        bottom.spacing = 6
        previewLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let labels = UIStackView(arrangedSubviews: [top, bottom])
        labels.axis = .vertical
        labels.spacing = 4
        labels.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(avatarView)
        contentView.addSubview(labels)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 52),
            avatarView.heightAnchor.constraint(equalToConstant: 52),

            labels.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            labels.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            labels.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            pinView.widthAnchor.constraint(equalToConstant: 12),
            pinView.heightAnchor.constraint(equalToConstant: 12),
            muteView.widthAnchor.constraint(equalToConstant: 14),
            muteView.heightAnchor.constraint(equalToConstant: 14),
            badgeLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20)
        ])
    }

    func configure(item: InboxItem, theme: ConversationTheme) {
        self.theme = theme
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        let unread = item.unreadCount > 0
        titleLabel.font = unread
            ? .systemFont(ofSize: 16, weight: .semibold)
            : .systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = theme.colors.headerTitle
        titleLabel.text = item.title

        timeLabel.font = theme.fonts.metadata
        timeLabel.textColor = unread ? theme.colors.accent : theme.colors.metadata
        timeLabel.text = BimbelFormatters.relativeTime(item.timestamp)

        previewLabel.font = theme.fonts.headerSubtitle
        if item.isTyping {
            previewLabel.text = String(localized: "Typing…")
            previewLabel.textColor = theme.colors.accent
        } else {
            previewLabel.text = item.preview
            previewLabel.textColor = theme.colors.headerSubtitle
        }

        pinView.isHidden = !item.isPinned
        pinView.tintColor = theme.colors.metadata
        muteView.isHidden = !item.isMuted
        muteView.tintColor = theme.colors.metadata

        if let badge = BimbelFormatters.badgeText(item.unreadCount) {
            badgeLabel.isHidden = false
            badgeLabel.text = badge
            badgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            badgeLabel.textColor = theme.colors.badgeText
            badgeLabel.backgroundColor = theme.colors.accent
            badgeLabel.layer.cornerRadius = 10
        } else {
            badgeLabel.isHidden = true
        }

        avatarView.layer.cornerRadius = 26
        let fallbackTitle = item.isGroup ? "G" : item.title
        avatarView.image = ImageLoader.image(from: item.avatar)
            ?? InitialGlyph.make(title: fallbackTitle, size: 52, colors: theme.colors)
        if let avatar = item.avatar {
            ImageLoader.load(avatar) { [weak self] image in
                if let image { self?.avatarView.image = image }
            }
        }

        accessibilityLabel = accessibility(for: item)
    }

    private func accessibility(for item: InboxItem) -> String {
        var parts = [item.title]
        if item.isTyping {
            parts.append(String(localized: "Typing"))
        } else {
            parts.append(item.preview)
        }
        if item.unreadCount > 0 {
            parts.append("\(item.unreadCount)")
        }
        if item.isPinned { parts.append(String(localized: "Pinned")) }
        if item.isMuted { parts.append(String(localized: "Muted")) }
        return parts.joined(separator: ", ")
    }
}
