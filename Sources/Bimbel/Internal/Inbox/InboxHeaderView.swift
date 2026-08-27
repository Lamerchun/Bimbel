import UIKit

final class InboxHeaderView: UIView, UITextFieldDelegate {
    var onQueryChange: ((String) -> Void)?
    var onTitleTap: (() -> Void)?
    var onFilterChange: ((Bool) -> Void)?

    private let glass = MaterialFactory.makeHeaderEffectView(theme: .default)
    private let content = UIView()
    private let titleLabel = UILabel()
    private let searchField = UITextField()
    private let allChip = HitTargetButton(type: .system)
    private let unreadChip = HitTargetButton(type: .system)
    private var theme = ConversationTheme.default
    private var unreadOnly = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var contentHeight: CGFloat { 132 }

    private func setup() {
        backgroundColor = .clear
        addSubview(glass)
        glass.bimbelPinToEdges(of: self)

        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.numberOfLines = 1
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapTitle)))
        titleLabel.accessibilityTraits = .header

        searchField.placeholder = String(localized: "Search")
        searchField.borderStyle = .none
        searchField.leftView = searchGlyph()
        searchField.leftViewMode = .always
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .search
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.layer.masksToBounds = true

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

        [titleLabel, searchField, chips].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.heightAnchor.constraint(equalToConstant: 132),

            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 36),

            chips.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            chips.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            chips.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            chips.heightAnchor.constraint(equalToConstant: 32),
            allChip.heightAnchor.constraint(equalToConstant: 32),
            unreadChip.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    func apply(title: String, theme: ConversationTheme) {
        self.theme = theme
        titleLabel.text = title
        titleLabel.textColor = theme.colors.headerTitle
        searchField.backgroundColor = theme.colors.composerFill
        searchField.textColor = theme.colors.incomingPrimaryText
        searchField.tintColor = theme.colors.accent
        searchField.layer.cornerRadius = 18
        searchField.layer.borderWidth = 0.5
        searchField.layer.borderColor = theme.colors.composerStroke.cgColor
        searchField.font = theme.fonts.body
        paintChips()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func searchGlyph() -> UIView {
        let wrap = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        icon.frame = CGRect(x: 10, y: 8, width: 18, height: 20)
        wrap.addSubview(icon)
        return wrap
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

    @objc private func searchChanged() {
        onQueryChange?(searchField.text ?? "")
    }

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
