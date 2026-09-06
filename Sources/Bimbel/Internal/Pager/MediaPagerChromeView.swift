import UIKit

/// Thin header-family chrome. Close · Save · Forward — ultraLight line, no plates, no extra accent.
final class MediaPagerChromeView: UIView {
    var onClose: (() -> Void)?
    var onSave: (() -> Void)?
    var onForward: (() -> Void)?

    private let glass: UIVisualEffectView
    private let closeButton = HitTargetButton(type: .system)
    private let saveButton = HitTargetButton(type: .system)
    private let forwardButton = HitTargetButton(type: .system)
    private var heightConstraint: NSLayoutConstraint?

    init(theme: ConversationTheme) {
        glass = MaterialFactory.makeHeaderEffectView(theme: theme)
        super.init(frame: .zero)
        setup(theme: theme)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(theme: ConversationTheme) {
        isOpaque = false
        backgroundColor = .clear
        addSubview(glass)
        glass.bimbelPinToEdges(of: self)
        glass.isOpaque = false
        glass.backgroundColor = .clear

        let tint = UIColor.white
        style(closeButton, symbol: "xmark", theme: theme, tint: tint)
        style(saveButton, symbol: "square.and.arrow.down", theme: theme, tint: tint)
        style(forwardButton, symbol: "arrowshape.turn.up.right", theme: theme, tint: tint)
        closeButton.accessibilityLabel = String(localized: "Close")
        saveButton.accessibilityLabel = String(localized: "Save")
        forwardButton.accessibilityLabel = String(localized: "Forward")
        closeButton.addTarget(self, action: #selector(tapClose), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(tapSave), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(tapForward), for: .touchUpInside)

        let trailing = UIStackView(arrangedSubviews: [saveButton, forwardButton])
        trailing.axis = .horizontal
        trailing.spacing = 4
        [closeButton, trailing].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        let height = heightAnchor.constraint(equalToConstant: theme.layout.headerHeightCompact + 47)
        heightConstraint = height
        NSLayoutConstraint.activate([
            height,
            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            closeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            closeButton.widthAnchor.constraint(equalToConstant: theme.layout.hitTarget),
            closeButton.heightAnchor.constraint(equalToConstant: theme.layout.hitTarget),
            trailing.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            trailing.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor)
        ])
    }

    func applySafeTop(_ top: CGFloat, theme: ConversationTheme) {
        heightConstraint?.constant = theme.layout.headerHeightCompact + top
    }

    private func style(_ button: HitTargetButton, symbol: String, theme: ConversationTheme, tint: UIColor) {
        button.backgroundColor = .clear
        button.minimumHitSize = CGSize(width: theme.layout.hitTarget, height: theme.layout.hitTarget)
        let config = UIImage.SymbolConfiguration(pointSize: theme.layout.headerIcon, weight: .ultraLight)
        button.setImage(UIImage(systemName: symbol, withConfiguration: config)?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = tint
    }

    @objc private func tapClose() { onClose?() }
    @objc private func tapSave() { onSave?() }
    @objc private func tapForward() { onForward?() }
}
