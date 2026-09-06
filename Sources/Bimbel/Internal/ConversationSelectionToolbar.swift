import UIKit

enum ConversationSelectionChrome {
    static let deleteFill = UIColor.systemRed
    static let forwardFill = UIColor.secondarySystemFill
}

final class ConversationSelectionToolbar: UIView {
    var onForward: (() -> Void)?
    var onDelete: (() -> Void)?

    private let forwardButton = HitTargetButton(type: .system)
    private let deleteButton = HitTargetButton(type: .system)
    private let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 52)
    }

    var forwardFillColor: UIColor? { forwardButton.configuration?.background.backgroundColor }
    var deleteFillColor: UIColor? { deleteButton.configuration?.background.backgroundColor }

    private func setup() {
        countLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        countLabel.textAlignment = .center
        forwardButton.addTarget(self, action: #selector(tapForward), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(tapDelete), for: .touchUpInside)
        forwardButton.accessibilityLabel = String(localized: "Forward")
        deleteButton.accessibilityLabel = String(localized: "Delete")

        let row = UIStackView(arrangedSubviews: [forwardButton, countLabel, deleteButton])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalCentering
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        addSubview(row)
        row.bimbelPinToEdges(of: self)
        heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
    }

    func apply(theme: ConversationTheme, selectedCount: Int) {
        backgroundColor = theme.colors.composerFill
        countLabel.textColor = theme.colors.headerTitle
        countLabel.text = selectedCount == 0
            ? String(localized: "Select")
            : "\(selectedCount)"
        style(
            forwardButton,
            title: String(localized: "Forward"),
            symbol: "arrowshape.turn.up.right",
            fill: ConversationSelectionChrome.forwardFill,
            foreground: theme.colors.headerTitle,
            enabled: selectedCount > 0
        )
        style(
            deleteButton,
            title: String(localized: "Delete"),
            symbol: "trash",
            fill: ConversationSelectionChrome.deleteFill,
            foreground: .white,
            enabled: selectedCount > 0
        )
    }

    private func style(
        _ button: UIButton,
        title: String,
        symbol: String,
        fill: UIColor,
        foreground: UIColor,
        enabled: Bool
    ) {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: symbol, withConfiguration: .bimbelComposerLine)
        config.imagePlacement = .leading
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        config.baseForegroundColor = foreground
        config.background.backgroundColor = fill
        config.background.cornerRadius = 18
        config.background.strokeWidth = 0
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 15, weight: .semibold)
            return outgoing
        }
        button.configuration = config
        button.backgroundColor = .clear
        button.isEnabled = enabled
        button.alpha = enabled ? 1 : 0.45
    }

    @objc private func tapForward() { onForward?() }
    @objc private func tapDelete() { onDelete?() }
}
