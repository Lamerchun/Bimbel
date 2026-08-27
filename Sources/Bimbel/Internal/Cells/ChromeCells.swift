import UIKit

final class DateChipCell: UICollectionViewCell {
    static let reuseID = "DateChipCell"
    private let label = PaddedLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        label.textAlignment = .center
        label.layer.masksToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(date: Date, theme: ConversationTheme) {
        label.font = theme.fonts.chip
        label.textColor = theme.colors.systemChipText
        label.backgroundColor = theme.colors.systemChipFill
        label.layer.cornerRadius = theme.radii.chip
        label.insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        label.text = BimbelFormatters.dateChipText(date)
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let size = label.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        attributes.frame.size = CGSize(width: ceil(size.width), height: 36)
        return attributes
    }
}

final class UnreadSeparatorCell: UICollectionViewCell {
    static let reuseID = "UnreadSeparatorCell"
    private let label = PaddedLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        label.text = String(localized: "Unread messages")
        label.textAlignment = .center
        label.layer.masksToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(theme: ConversationTheme) {
        // Same chip language as the date separator. No accent hairline.
        label.font = theme.fonts.chip
        label.textColor = theme.colors.systemChipText
        label.backgroundColor = theme.colors.systemChipFill
        label.layer.cornerRadius = theme.radii.chip
        label.insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let size = label.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
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
