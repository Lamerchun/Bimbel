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
    private var diffable: UITableViewDiffableDataSource<InboxListSection, ConversationID>!
    private let headerView = InboxHeaderView()
    private let searchController = UISearchController(searchResultsController: nil)
    private var headerHeightConstraint: NSLayoutConstraint?
    private var snapshot = InboxSnapshot(items: [])
    private var query = ""
    private var unreadOnly = false
    private var didPreferTablePanOverPop = false
    /// `apply` while off-window stores rows and waits. Flush on appear.
    private var pendingVisibleReload = false

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
        NavigationChrome.hideSystemBar(in: self, animated: false)
        definesPresentationContext = true
        view.backgroundColor = theme.colors.wallpaper
        configureSearch()
        configureHierarchy()
        configureTable()
        apply(dataSource.snapshot(), animatingDifferences: false)
        applyChrome()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NavigationChrome.hideSystemBar(in: self, animated: animated)
        preferTablePanOverInteractivePop()
        if pendingVisibleReload {
            reloadVisible(animating: false)
        }
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
        let previous = itemsByID
        self.snapshot = snapshot
        if canReconfigureTyping(from: previous, to: snapshot.items) {
            guard canMutateTable else {
                pendingVisibleReload = true
                return
            }
            updateVisibleTyping(from: previous)
            return
        }
        reloadVisible(animating: animatingDifferences)
    }

    private var itemsByID: [ConversationID: InboxItem] {
        Dictionary(uniqueKeysWithValues: snapshot.items.map { ($0.id, $0) })
    }

    private func configureSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = String(localized: "Search")
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.returnKeyType = .search
    }

    private func configureHierarchy() {
        wallpaper.backgroundColor = theme.colors.wallpaper
        view.addSubview(wallpaper)
        wallpaper.bimbelPinToEdges(of: view)

        tableView.backgroundColor = .clear
        tableView.isOpaque = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.separatorInset = UIEdgeInsets(
            top: 0,
            left: theme.layout.inboxSeparatorInset,
            bottom: 0,
            right: 0
        )
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = InboxRowMetrics.estimatedRowHeight(theme: theme)
        tableView.keyboardDismissMode = .onDrag
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.bimbelPinToEdges(of: view)

        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.embedSearchBar(searchController.searchBar)
        let height = headerView.heightAnchor.constraint(equalToConstant: 180)
        headerHeightConstraint = height
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            height
        ])
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
        diffable = UITableViewDiffableDataSource<InboxListSection, ConversationID>(tableView: tableView) {
            [weak self] tableView, indexPath, id in
            guard let self,
                  let item = self.snapshot.items.first(where: { $0.id == id })
            else { return UITableViewCell() }
            let cell = tableView.dequeueReusableCell(
                withIdentifier: InboxRowCell.reuseID,
                for: indexPath
            ) as! InboxRowCell
            cell.configure(
                item: item,
                theme: self.theme,
                hidesTrailingAccessories: self.isSearchOverride
            )
            return cell
        }
        diffable.defaultRowAnimation = .fade
    }

    private var isSearchOverride: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func applyChrome() {
        wallpaper.backgroundColor = theme.colors.wallpaper
        view.backgroundColor = theme.colors.wallpaper
        tableView.separatorColor = theme.colors.composerStroke
        tableView.separatorInset = UIEdgeInsets(
            top: 0,
            left: theme.layout.inboxSeparatorInset,
            bottom: 0,
            right: 0
        )
        tableView.backgroundColor = .clear
        tableView.estimatedRowHeight = InboxRowMetrics.estimatedRowHeight(theme: theme)
        headerView.apply(title: titleText, theme: theme)
        guard canMutateTable else { return }
        tableView.reloadData()
    }

    /// Covered inbox (thread pushed) still has a window. Applying / reloading
    /// it from `onSendVoice` / `onSendText` is the post-voice EXC_BREAKPOINT.
    private var canMutateTable: Bool {
        guard isViewLoaded, view.window != nil else { return false }
        if let nav = navigationController {
            return nav.topViewController === self
        }
        return true
    }

    private func reloadVisible(animating: Bool) {
        guard isViewLoaded else { return }
        guard canMutateTable else {
            pendingVisibleReload = true
            return
        }
        pendingVisibleReload = false
        let parts = InboxFiltering.sections(items: snapshot.items, query: query, unreadOnly: unreadOnly)
        var next = NSDiffableDataSourceSnapshot<InboxListSection, ConversationID>()
        if !parts.pinned.isEmpty {
            next.appendSections([.pinned])
            next.appendItems(parts.pinned.map(\.id), toSection: .pinned)
        }
        next.appendSections([.chats])
        next.appendItems(parts.chats.map(\.id), toSection: .chats)
        let current = diffable.snapshot()
        if current.itemIdentifiers == next.itemIdentifiers,
           current.sectionIdentifiers == next.sectionIdentifiers
        {
            // Reconfigure the *live* snapshot. A fresh empty snapshot with the
            // same ids still trips UITableViewDiffableDataSource (SpringBoard).
            var live = current
            live.reconfigureItems(current.itemIdentifiers)
            diffable.apply(live, animatingDifferences: false)
        } else {
            diffable.apply(next, animatingDifferences: animating)
        }
    }

    private func canReconfigureTyping(from previous: [ConversationID: InboxItem], to next: [InboxItem]) -> Bool {
        guard previous.count == next.count else { return false }
        for item in next {
            guard let old = previous[item.id] else { return false }
            var probe = old
            probe.isTyping = item.isTyping
            if probe != item { return false }
        }
        return true
    }

    private func updateVisibleTyping(from previous: [ConversationID: InboxItem]) {
        for cell in tableView.visibleCells {
            guard let row = cell as? InboxRowCell,
                  let indexPath = tableView.indexPath(for: row),
                  let item = item(at: indexPath)
            else { continue }
            if previous[item.id]?.isTyping != item.isTyping {
                row.applyTyping(item.isTyping)
            }
        }
    }

    private func item(at indexPath: IndexPath) -> InboxItem? {
        guard let id = diffable.itemIdentifier(for: indexPath) else { return nil }
        return snapshot.items.first(where: { $0.id == id })
    }

    /// The nav pop gesture sits on the leading edge and swallows Read/Pin.
    /// Disable pop when this list is the root. If the host pushed the inbox,
    /// prefer the table pan so leading swipe still opens.
    private func preferTablePanOverInteractivePop() {
        guard let nav = navigationController,
              let pop = nav.interactivePopGestureRecognizer
        else { return }
        if nav.viewControllers.first === self {
            pop.isEnabled = false
            return
        }
        guard !didPreferTablePanOverPop else { return }
        pop.require(toFail: tableView.panGestureRecognizer)
        didPreferTablePanOverPop = true
    }
}

extension InboxViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = item(at: indexPath) else { return }
        actions.onOpen?(item.id)
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard diffable.sectionIdentifier(for: section) == .pinned else { return nil }
        let wrap = UIView()
        wrap.backgroundColor = .clear
        let label = UILabel()
        label.text = String(localized: "Pinned")
        label.font = theme.fonts.chip
        label.textColor = theme.colors.metadata
        label.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -4)
        ])
        return wrap
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        diffable.sectionIdentifier(for: section) == .pinned ? 28 : 0
    }

    public func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let item = item(at: indexPath) else { return nil }
        let read = UIContextualAction(
            style: .normal,
            title: item.showsUnread ? String(localized: "Read") : String(localized: "Unread")
        ) { [weak self] _, _, done in
            self?.actions.onToggleRead?(item.id)
            done(true)
        }
        read.backgroundColor = InboxSwipeChrome.readFill(theme: theme)
        read.image = InboxSwipeChrome.symbol(item.showsUnread ? "envelope.open" : "envelope.badge")
        let pin = UIContextualAction(
            style: .normal,
            title: item.isPinned ? String(localized: "Unpin") : String(localized: "Pin")
        ) { [weak self] _, _, done in
            self?.actions.pin(item.id)
            done(true)
        }
        pin.backgroundColor = InboxSwipeChrome.pinFill
        pin.image = InboxSwipeChrome.symbol(item.isPinned ? "pin.slash" : "pin")
        let config = UISwipeActionsConfiguration(actions: [read, pin])
        config.performsFirstActionWithFullSwipe = false
        return config
    }

    public func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let item = item(at: indexPath) else { return nil }
        let mute = UIContextualAction(
            style: .normal,
            title: item.isMuted ? String(localized: "Unmute") : String(localized: "Mute")
        ) { [weak self] _, _, done in
            self?.actions.mute(item.id)
            done(true)
        }
        mute.backgroundColor = InboxSwipeChrome.muteFill
        mute.image = InboxSwipeChrome.symbol(item.isMuted ? "bell" : "bell.slash")
        let delete = UIContextualAction(style: .destructive, title: String(localized: "Delete")) { [weak self] _, _, done in
            self?.actions.onDelete?(item.id)
            done(true)
        }
        delete.backgroundColor = InboxSwipeChrome.deleteFill
        delete.image = InboxSwipeChrome.symbol("trash")
        // First action sits at the trailing edge; delete is last in the catalog and at the edge.
        let config = UISwipeActionsConfiguration(actions: [delete, mute])
        config.performsFirstActionWithFullSwipe = false
        return config
    }

    public func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let item = item(at: indexPath) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            var children: [UIMenuElement] = [
                UIAction(
                    title: item.showsUnread ? String(localized: "Read") : String(localized: "Unread")
                ) { _ in
                    self.actions.onToggleRead?(item.id)
                },
                UIAction(title: item.isPinned ? String(localized: "Unpin") : String(localized: "Pin")) { _ in
                    self.actions.pin(item.id)
                },
                UIAction(title: item.isMuted ? String(localized: "Unmute") : String(localized: "Mute")) { _ in
                    self.actions.mute(item.id)
                }
            ]
            if self.actions.offersArchive {
                children.append(UIAction(title: String(localized: "Archive")) { _ in
                    self.actions.onArchive?(item.id)
                })
            }
            children.append(UIAction(title: String(localized: "Delete"), attributes: .destructive) { _ in
                self.actions.onDelete?(item.id)
            })
            return UIMenu(children: children)
        }
    }
}

extension InboxViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        query = searchController.searchBar.text ?? ""
        actions.onSearch?(query)
        reloadVisible(animating: false)
    }
}
