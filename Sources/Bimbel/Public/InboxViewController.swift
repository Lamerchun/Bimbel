import UIKit

/// UIKit inbox (Unterhaltungsübersicht). Call `apply(_:animatingDifferences:)` when rows change.
/// Host owns data. The package never mints `ConversationID`s.
@MainActor
open class InboxViewController: UIViewController {
    public let dataSource: any InboxDataSource
    public var theme: ConversationTheme {
        didSet { applyChrome() }
    }
    public var actions: InboxActions
    public var titleText: String {
        didSet { headerView.apply(title: titleText, theme: theme) }
    }

    private let wallpaper = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var diffable: UITableViewDiffableDataSource<Int, ConversationID>!
    private let headerView = InboxHeaderView()
    private var headerHeightConstraint: NSLayoutConstraint?
    private var snapshot = InboxSnapshot(items: [])
    private var query = ""
    private var unreadOnly = false

    public init(
        dataSource: any InboxDataSource,
        theme: ConversationTheme = .default,
        title: String? = nil,
        actions: InboxActions = InboxActions()
    ) {
        self.dataSource = dataSource
        self.theme = theme
        self.titleText = title ?? String(localized: "Chats")
        self.actions = actions
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        view.backgroundColor = theme.colors.wallpaper
        configureHierarchy()
        configureTable()
        apply(dataSource.snapshot(), animatingDifferences: false)
        applyChrome()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        headerHeightConstraint?.constant = view.safeAreaInsets.top + headerView.contentHeight
        let top = headerView.bounds.height
        if tableView.contentInset.top != top {
            tableView.contentInset.top = top
            tableView.verticalScrollIndicatorInsets.top = top
            tableView.scrollIndicatorInsets.top = top
        }
    }

    public func apply(_ snapshot: InboxSnapshot, animatingDifferences: Bool) {
        self.snapshot = snapshot
        reloadVisible(animating: animatingDifferences)
    }

    private func configureHierarchy() {
        wallpaper.backgroundColor = theme.colors.wallpaper
        view.addSubview(wallpaper)
        wallpaper.bimbelPinToEdges(of: view)

        tableView.backgroundColor = .clear
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 78, bottom: 0, right: 0)
        tableView.rowHeight = 68
        tableView.estimatedRowHeight = 68
        tableView.keyboardDismissMode = .onDrag
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.bimbelPinToEdges(of: view)

        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        let height = headerView.heightAnchor.constraint(equalToConstant: 180)
        headerHeightConstraint = height
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            height
        ])
        headerView.onQueryChange = { [weak self] query in
            guard let self else { return }
            self.query = query
            self.actions.onSearch?(query)
            self.reloadVisible(animating: false)
        }
        headerView.onFilterChange = { [weak self] unreadOnly in
            self?.unreadOnly = unreadOnly
            self?.reloadVisible(animating: true)
        }
        headerView.onTitleTap = { [weak self] in
            self?.actions.onTitleTap?()
        }
    }

    private func configureTable() {
        tableView.register(InboxRowCell.self, forCellReuseIdentifier: InboxRowCell.reuseID)
        diffable = UITableViewDiffableDataSource<Int, ConversationID>(tableView: tableView) { [weak self] tableView, indexPath, id in
            guard let self,
                  let item = self.snapshot.items.first(where: { $0.id == id })
            else { return UITableViewCell() }
            let cell = tableView.dequeueReusableCell(withIdentifier: InboxRowCell.reuseID, for: indexPath) as! InboxRowCell
            cell.configure(item: item, theme: self.theme)
            return cell
        }
        diffable.defaultRowAnimation = .fade
    }

    private func applyChrome() {
        wallpaper.backgroundColor = theme.colors.wallpaper
        view.backgroundColor = theme.colors.wallpaper
        tableView.separatorColor = theme.colors.composerStroke
        tableView.backgroundColor = .clear
        headerView.apply(title: titleText, theme: theme)
        tableView.reloadData()
    }

    private func reloadVisible(animating: Bool) {
        let items = InboxFiltering.visible(items: snapshot.items, query: query, unreadOnly: unreadOnly)
        var next = NSDiffableDataSourceSnapshot<Int, ConversationID>()
        next.appendSections([0])
        next.appendItems(items.map(\.id), toSection: 0)
        diffable.apply(next, animatingDifferences: animating)
    }

    private func item(at indexPath: IndexPath) -> InboxItem? {
        guard let id = diffable.itemIdentifier(for: indexPath) else { return nil }
        return snapshot.items.first(where: { $0.id == id })
    }
}

extension InboxViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = item(at: indexPath) else { return }
        actions.onOpen?(item.id)
    }

    public func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let item = item(at: indexPath) else { return nil }
        let pin = UIContextualAction(style: .normal, title: item.isPinned ? String(localized: "Unpin") : String(localized: "Pin")) { [weak self] _, _, done in
            self?.actions.onPin?(item.id)
            done(true)
        }
        pin.backgroundColor = theme.colors.accent
        let mute = UIContextualAction(style: .normal, title: item.isMuted ? String(localized: "Unmute") : String(localized: "Mute")) { [weak self] _, _, done in
            self?.actions.onMute?(item.id)
            done(true)
        }
        mute.backgroundColor = .systemGray
        let config = UISwipeActionsConfiguration(actions: [pin, mute])
        config.performsFirstActionWithFullSwipe = false
        return config
    }

    public func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let item = item(at: indexPath) else { return nil }
        let delete = UIContextualAction(style: .destructive, title: String(localized: "Delete")) { [weak self] _, _, done in
            self?.actions.onDelete?(item.id)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
