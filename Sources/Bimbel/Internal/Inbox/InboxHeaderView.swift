import UIKit

final class InboxHeaderView: UIView {
    var onTitleTap: (() -> Void)?
    var onFilterChange: ((Bool) -> Void)?

    private let glass = MaterialFactory.makeHeaderEffectView(theme: .default)
    private let content = UIView()
    private let titleLabel = UILabel()
    private let searchHost = UIView()
    private let allChip = HitTargetButton(type: .system)
    private let unreadChip = HitTargetButton(type: .system)
    private var theme = ConversationTheme.default
    private var unreadOnly = false
    private var embeddedSearchBar: UISearchBar?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var contentHeight: CGFloat { 128 }

    func embedSearchBar(_ searchBar: UISearchBar) {
        embeddedSearchBar?.removeFromSuperview()
        embeddedSearchBar = searchBar
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchHost.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: searchHost.leadingAnchor, constant: -8),
            searchBar.trailingAnchor.constraint(equalTo: searchHost.trailingAnchor, constant: 8),
            searchBar.topAnchor.constraint(equalTo: searchHost.topAnchor),
            searchBar.bottomAnchor.constraint(equalTo: searchHost.bottomAnchor)
        ])
        paintSearchBar()
    }

    private func setup() {
        isOpaque = false
        backgroundColor = .clear
        layer.shadowOpacity = 0
        addSubview(glass)
        glass.isOpaque = false
        glass.backgroundColor = .clear
        glass.bimbelPinToEdges(of: self)

        content.translatesAutoresizingMaskIntoConstraints = false
        content.backgroundColor = .clear
        content.isOpaque = false
        addSubview(content)

        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.numberOfLines = 1
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapTitle)))
        titleLabel.accessibilityTraits = .header

        searchHost.translatesAutoresizingMaskIntoConstraints = false

        var allConfig = UIButton.Configuration.plain()
        allConfig.title = String(localized: "All")
        allChip.configuration = allConfig
        var unreadConfig = UIButton.Configuration.plain()
        unreadConfig.title = String(localized: "Unread")
        unreadChip.configuration = unreadConfig
        allChip.addTarget(self, action: #selector(tapAll), for: .touchUpInside)
        unreadChip.addTarget(self, action: #selector(tapUnread), for: .touchUpInside)

        let chips = UIStackView(arrangedSubviews: [allChip, unreadChip, UIView()])
        chips.axis = .horizontal
        chips.spacing = 8
        chips.alignment = .center

        [titleLabel, searchHost, chips].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.heightAnchor.constraint(equalToConstant: 128),

            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            searchHost.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            searchHost.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            searchHost.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            searchHost.heightAnchor.constraint(equalToConstant: 44),

            chips.topAnchor.constraint(equalTo: searchHost.bottomAnchor, constant: 6),
            chips.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            chips.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            chips.heightAnchor.constraint(equalToConstant: 32),
            allChip.heightAnchor.constraint(equalToConstant: 32),
            unreadChip.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    func apply(title: String, theme: ConversationTheme) {
        self.theme = theme
        isOpaque = false
        backgroundColor = .clear
        glass.isOpaque = false
        glass.backgroundColor = .clear
        if theme.materials.usesLiquidGlassWhenAvailable, let effect = MaterialFactory.makeLiquidGlassEffect() {
            glass.effect = effect
        } else {
            glass.effect = UIBlurEffect(style: theme.materials.headerBlurStyle)
        }
        titleLabel.text = title
        titleLabel.textColor = theme.colors.headerTitle
        paintSearchBar()
        paintChips()
    }

    private func paintSearchBar() {
        guard let searchBar = embeddedSearchBar else { return }
        searchBar.tintColor = theme.colors.accent
        searchBar.searchTextField.backgroundColor = theme.colors.composerFill
        searchBar.searchTextField.textColor = theme.colors.incomingPrimaryText
        searchBar.searchTextField.leftView?.tintColor = theme.colors.metadata
        searchBar.searchTextField.font = theme.fonts.body
    }

    private func paintChips() {
        style(allChip, selected: !unreadOnly)
        style(unreadChip, selected: unreadOnly)
    }

    private func style(_ button: UIButton, selected: Bool) {
        var config = button.configuration ?? .plain()
        config.title = button.configuration?.title ?? button.title(for: .normal)
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.baseForegroundColor = selected ? UIColor.white : theme.colors.headerTitle
        config.background.backgroundColor = selected ? theme.colors.accent : theme.colors.composerFill
        config.background.cornerRadius = 16
        let font = theme.fonts.chip
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = font
            return outgoing
        }
        button.configuration = config
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
    }

    @objc private func tapTitle() { onTitleTap?() }

    @objc private func tapAll() {
        unreadOnly = false
        paintChips()
        onFilterChange?(false)
    }

    @objc private func tapUnread() {
        unreadOnly = true
        paintChips()
        onFilterChange?(true)
    }
}
