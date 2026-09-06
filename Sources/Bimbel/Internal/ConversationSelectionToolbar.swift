import UIKit

final class ConversationSelectionToolbar: UIView {
    var onForward: (() -> Void)?
    var onDelete: (() -> Void)?

    private let forwardButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 52)
    }

    private func setup() {
        forwardButton.setTitle(String(localized: "Forward"), for: .normal)
        forwardButton.addTarget(self, action: #selector(tapForward), for: .touchUpInside)
        deleteButton.setTitle(String(localized: "Delete"), for: .normal)
        deleteButton.addTarget(self, action: #selector(tapDelete), for: .touchUpInside)
        countLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        countLabel.textAlignment = .center

        let row = UIStackView(arrangedSubviews: [forwardButton, countLabel, deleteButton])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalCentering
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
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
        forwardButton.tintColor = theme.colors.accent
        forwardButton.setTitleColor(theme.colors.accent, for: .normal)
        forwardButton.isEnabled = selectedCount > 0
        deleteButton.tintColor = .systemRed
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.isEnabled = selectedCount > 0
    }

    @objc private func tapForward() { onForward?() }
    @objc private func tapDelete() { onDelete?() }
}
