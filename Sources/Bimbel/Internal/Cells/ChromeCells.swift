import UIKit

/// Centered pill used by the date chip and the unread marker. No hairline.
final class ChromeChipView: PaddedLabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        textAlignment = .center
        layer.masksToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(text: String, theme: ConversationTheme) {
        self.text = text
        font = theme.fonts.chip
        textColor = theme.colors.systemChipText
        backgroundColor = theme.colors.systemChipFill
        layer.cornerRadius = theme.radii.chip
        insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
    }
}

final class DateChipCell: UICollectionViewCell {
    static let reuseID = "DateChipCell"
    private let chip = ChromeChipView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(chip)
        chip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chip.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            chip.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            chip.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(date: Date, theme: ConversationTheme) {
        chip.apply(text: BimbelFormatters.dateChipText(date), theme: theme)
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let size = chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        attributes.frame.size = CGSize(width: ceil(size.width), height: 36)
        return attributes
    }
}

final class UnreadSeparatorCell: UICollectionViewCell {
    static let reuseID = "UnreadSeparatorCell"
    private let chip = ChromeChipView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(chip)
        chip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chip.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            chip.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            chip.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(theme: ConversationTheme) {
        chip.apply(text: String(localized: "Unread messages"), theme: theme)
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let size = chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        attributes.frame.size = CGSize(width: ceil(size.width), height: 36)
        return attributes
    }
}

final class SystemMessageCell: UICollectionViewCell {
    static let reuseID = "SystemMessageCell"
    private let label = PaddedLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        label.numberOfLines = 0
        label.textAlignment = .center
        label.layer.masksToBounds = true
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String, theme: ConversationTheme) {
        label.font = theme.fonts.chip
        label.textColor = theme.colors.systemChipText
        label.backgroundColor = theme.colors.systemChipFill
        label.layer.cornerRadius = theme.radii.chip
        label.insets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        label.text = text
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let target = CGSize(width: layoutAttributes.frame.width, height: UIView.layoutFittingCompressedSize.height)
        let size = contentView.systemLayoutSizeFitting(target, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        attributes.frame.size = CGSize(width: layoutAttributes.frame.width, height: max(32, ceil(size.height)))
        return attributes
    }
}
