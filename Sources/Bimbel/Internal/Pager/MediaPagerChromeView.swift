import UIKit

/// Ship 5 lock. Close · Save · Forward over thin `material.header`, same family as the thread header.
enum ConversationPagerChrome {
    static let symbols = ["xmark", "square.and.arrow.down", "arrowshape.turn.up.right"]
}

final class MediaPagerChromeView: UIView {
    var onClose: (() -> Void)?
    var onSave: (() -> Void)?
    var onForward: (() -> Void)?

    private let glass: UIVisualEffectView
    private let content = UIView()
    private let closeButton = HitTargetButton(type: .system)
    private let saveButton = HitTargetButton(type: .system)
    private let forwardButton = HitTargetButton(type: .system)
    private var heightConstraint: NSLayoutConstraint?
    private var contentHeight: NSLayoutConstraint?
    private var theme: ConversationTheme

    init(theme: ConversationTheme) {
        self.theme = theme
        glass = MaterialFactory.makeHeaderEffectView(theme: theme)
        super.init(frame: .zero)
        setup()
        apply(theme: theme)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var headerTitleTint: UIColor? { closeButton.tintColor }
    var usesAccentTint: Bool {
        let accent = theme.colors.accent.cgColor
        return closeButton.tintColor?.cgColor == accent
            || saveButton.tintColor?.cgColor == accent
            || forwardButton.tintColor?.cgColor == accent
    }
    var buttonFillsAreClear: Bool {
        [closeButton, saveButton, forwardButton].allSatisfy { ($0.backgroundColor?.cgColor.alpha ?? 0) < 0.01 }
    }
    var hasHairline: Bool { layer.shadowOpacity > 0 || layer.borderWidth > 0 }

    private func setup() {
        isOpaque = false
        backgroundColor = .clear
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        addSubview(glass)
        glass.bimbelPinToEdges(of: self)
        glass.isOpaque = false
        glass.backgroundColor = .clear

        content.translatesAutoresizingMaskIntoConstraints = false
        content.backgroundColor = .clear
        content.isOpaque = false
        addSubview(content)

        style(closeButton, symbol: "xmark", label: String(localized: "Close"), action: #selector(tapClose))
        style(saveButton, symbol: "square.and.arrow.down", label: String(localized: "Save"), action: #selector(tapSave))
        style(forwardButton, symbol: "arrowshape.turn.up.right", label: String(localized: "Forward"), action: #selector(tapForward))

        let trailing = UIStackView(arrangedSubviews: [saveButton, forwardButton])
        trailing.axis = .horizontal
        trailing.spacing = 2
        [closeButton, trailing].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        let bar = theme.layout.headerHeightCompact
        heightConstraint = heightAnchor.constraint(equalToConstant: bar)
        contentHeight = content.heightAnchor.constraint(equalToConstant: bar)
        NSLayoutConstraint.activate([
            heightConstraint!,
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentHeight!,
            closeButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 4),
            closeButton.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: theme.layout.hitTarget),
            closeButton.heightAnchor.constraint(equalToConstant: theme.layout.hitTarget),
            trailing.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -6),
            trailing.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: theme.layout.hitTarget),
            saveButton.heightAnchor.constraint(equalToConstant: theme.layout.hitTarget),
            forwardButton.widthAnchor.constraint(equalToConstant: theme.layout.hitTarget),
            forwardButton.heightAnchor.constraint(equalToConstant: theme.layout.hitTarget)
        ])
    }

    func apply(theme: ConversationTheme) {
        self.theme = theme
        applyGlass(theme)
        let tint = theme.colors.headerTitle
        [closeButton, saveButton, forwardButton].forEach {
            $0.tintColor = tint
            $0.backgroundColor = .clear
        }
        closeButton.setImage(UIImage.bimbelComposerLine("xmark"), for: .normal)
        saveButton.setImage(UIImage.bimbelComposerLine("square.and.arrow.down"), for: .normal)
        forwardButton.setImage(UIImage.bimbelComposerLine("arrowshape.turn.up.right"), for: .normal)
        contentHeight?.constant = theme.layout.headerHeightCompact
    }

    func applySafeTop(_ top: CGFloat, theme: ConversationTheme) {
        heightConstraint?.constant = theme.layout.headerHeightCompact + top
    }

    private func applyGlass(_ theme: ConversationTheme) {
        isOpaque = false
        backgroundColor = .clear
        glass.isOpaque = false
        glass.backgroundColor = .clear
        if theme.materials.usesLiquidGlassWhenAvailable, let effect = MaterialFactory.makeLiquidGlassEffect() {
            glass.effect = effect
        } else {
            glass.effect = UIBlurEffect(style: theme.materials.headerBlurStyle)
        }
    }

    private func style(_ button: HitTargetButton, symbol: String, label: String, action: Selector) {
        button.backgroundColor = .clear
        button.minimumHitSize = CGSize(width: theme.layout.hitTarget, height: theme.layout.hitTarget)
        button.setImage(UIImage.bimbelComposerLine(symbol), for: .normal)
        button.accessibilityLabel = label
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func tapClose() { onClose?() }
    @objc private func tapSave() { onSave?() }
    @objc private func tapForward() { onForward?() }
}
