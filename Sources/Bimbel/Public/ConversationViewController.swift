import ChatLayout
import ContactsUI
import Photos
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// UIKit host. Call `apply(_:animatingDifferences:)` whenever messages change.
/// Pull-only arrays are not enough — the package will not poll the data source.
@MainActor
open class ConversationViewController: UIViewController {
    public let conversationID: ConversationID
    public let dataSource: any ConversationDataSource
    public var theme: ConversationTheme {
        didSet { applyChrome() }
    }
    public var header: HeaderContent {
        didSet { headerView.apply(content: header, theme: theme) }
    }
    public var actions: ConversationActions
    /// Host sets this before the conversation appears (e.g. `BIMBEL_SHOT=ada`).
    /// `viewDidAppear` focuses the layout-guide-pinned text view.
    public var presentsKeyboardOnAppear = false

    private let wallpaper = UIView()
    private let chatLayout = CollectionViewChatLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: chatLayout)
    private var diffable: UICollectionViewDiffableDataSource<ChatSection, ChatRow>!
    private let headerView = ConversationHeaderView()
    private let bottomChrome = UIStackView()
    private let composer = ComposerView()
    private let selectionToolbar = ConversationSelectionToolbar()
    private let keyboardTracker = ComposerKeyboardTracker()
    private let attachmentSheet = AttachmentSheetView()
    private let voice = VoiceRecordingController()
    private let voiceOverlay = VoiceLockOverlay()
    private let fab = HitTargetButton(type: .system)
    private var headerHeightConstraint: NSLayoutConstraint?
    private var snapshot: ConversationSnapshot
    private var rows: [ChatRow] = []
    private var replyTarget: Message?
    private var staged: [StagedAttachment] = []
    private var didBindKeyboard = false
    private var bottomBarConstraints: [NSLayoutConstraint] = []
    private var fabAboveComposer: NSLayoutConstraint?
    private var isLoadingOlder = false
    private var isNearBottom = true
    private var isSelecting = false
    private var selectedIDs: Set<MessageID> = []
    private weak var approvalController: MediaApprovalViewController?
    private let reactionPalette = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    public init(
        conversationID: ConversationID,
        dataSource: any ConversationDataSource,
        theme: ConversationTheme = .default,
        header: HeaderContent,
        actions: ConversationActions = ConversationActions()
    ) {
        self.conversationID = conversationID
        self.dataSource = dataSource
        self.theme = theme
        self.header = header
        self.actions = actions
        self.snapshot = dataSource.snapshot(in: conversationID)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        NavigationChrome.hideSystemBar(in: self, animated: false)
        view.backgroundColor = theme.colors.wallpaper
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        // Signal iOS 26: first access of `keyboardLayoutGuide` can report only
        // the home-indicator height (~34). Touch it before pinning the composer.
        _ = view.keyboardLayoutGuide
        configureHierarchy()
        configureCollection()
        configureHeader()
        configureComposer()
        configureVoice()
        apply(snapshot, animatingDifferences: false)
        applyChrome()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NavigationChrome.hideSystemBar(in: self, animated: animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        composer.textView.resignFirstResponder()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            keyboardTracker.detach()
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bindKeyboardIfNeeded()
        keyboardTracker.syncListInsets(flushingLayout: true)
        scrollToBottom(animated: false)
        if presentsKeyboardOnAppear {
            presentsKeyboardOnAppear = false
            presentKeyboard()
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderHeight()
        keyboardTracker.syncListInsets()
        updateTopInset()
    }

    /// Host-driven update path. Prefer this over mutating arrays the view already read.
    public func apply(_ snapshot: ConversationSnapshot, animatingDifferences: Bool) {
        self.snapshot = snapshot
        rows = MessageGrouping.rows(from: snapshot, maxGap: theme.grouping.maxGap)
        if isSelecting {
            let live = Set(snapshot.messages.map(\.id))
            selectedIDs = selectedIDs.intersection(live)
            refreshSelectionChrome()
        }
        var next = NSDiffableDataSourceSnapshot<ChatSection, ChatRow>()
        next.appendSections([.thread])
        next.appendItems(rows, toSection: .thread)
        let stickToBottom = isNearBottom
        diffable.apply(next, animatingDifferences: animatingDifferences)
        keyboardTracker.syncListInsets(flushingLayout: true)
        if stickToBottom {
            scrollToBottom(animated: animatingDifferences)
        }
        updateFAB()
    }

    /// Focus the layout-guide-pinned text view. The composer never leaves the VC.
    public func presentKeyboard() {
        loadViewIfNeeded()
        guard view.window != nil else {
            presentsKeyboardOnAppear = true
            return
        }
        bindKeyboardIfNeeded()
        composer.textView.becomeFirstResponder()
    }

    // MARK: - Hierarchy

    private func configureHierarchy() {
        wallpaper.backgroundColor = DoodleWallpaper.color(base: theme.colors.wallpaper)
        view.addSubview(wallpaper)
        wallpaper.bimbelPinToEdges(of: view)

        chatLayout.delegate = self
        chatLayout.keepContentOffsetAtBottomOnBatchUpdates = true
        chatLayout.keepContentAtBottomOfVisibleArea = true
        chatLayout.settings.estimatedItemSize = CGSize(width: UIScreen.main.bounds.width, height: 84)
        chatLayout.settings.interItemSpacing = theme.layout.groupingSequenceSpacing
        chatLayout.settings.additionalInsets = UIEdgeInsets(
            top: theme.layout.listComposerGap,
            left: 0,
            bottom: ComposerKeyboardTracker.layoutBottomPadding(
                composerHeight: bottomChrome.bounds.height,
                listComposerGap: theme.layout.listComposerGap
            ),
            right: 0
        )

        collectionView.backgroundColor = .clear
        collectionView.isOpaque = false
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .interactive
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.bimbelPinToEdges(of: view)

        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        let height = headerView.heightAnchor.constraint(equalToConstant: 100)
        headerHeightConstraint = height
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            height
        ])

        bottomChrome.axis = .vertical
        bottomChrome.alignment = .fill
        bottomChrome.translatesAutoresizingMaskIntoConstraints = false
        bottomChrome.addArrangedSubview(composer)
        bottomChrome.addArrangedSubview(selectionToolbar)
        selectionToolbar.isHidden = true
        view.addSubview(bottomChrome)
        updateBottomBar()

        view.addSubview(voiceOverlay)
        voiceOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            voiceOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            voiceOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            voiceOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            voiceOverlay.bottomAnchor.constraint(equalTo: bottomChrome.bottomAnchor)
        ])

        fab.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        fab.addTarget(self, action: #selector(tapFAB), for: .touchUpInside)
        fab.layer.shadowOpacity = 0.18
        fab.layer.shadowRadius = 8
        fab.layer.shadowOffset = CGSize(width: 0, height: 2)
        fab.isHidden = true
        view.addSubview(fab)
        fab.translatesAutoresizingMaskIntoConstraints = false
        fabAboveComposer = fab.bottomAnchor.constraint(equalTo: bottomChrome.topAnchor, constant: -10)
        NSLayoutConstraint.activate([
            fab.widthAnchor.constraint(equalToConstant: 44),
            fab.heightAnchor.constraint(equalToConstant: 44),
            fab.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            fabAboveComposer!
        ])
    }

    /// Signal `updateBottomBar()`. Composer stays in this VC and rides
    /// `keyboardLayoutGuide` when `shouldAttachToKeyboardLayoutGuide` is true.
    private func updateBottomBar() {
        NSLayoutConstraint.deactivate(bottomBarConstraints)
        let leading = bottomChrome.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let trailing = bottomChrome.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let bottom: NSLayoutConstraint
        if composer.shouldAttachToKeyboardLayoutGuide {
            bottom = bottomChrome.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        } else {
            bottom = bottomChrome.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        }
        bottomBarConstraints = [leading, trailing, bottom]
        NSLayoutConstraint.activate(bottomBarConstraints)
    }

    private func configureCollection() {
        collectionView.register(MessageCollectionCell.self, forCellWithReuseIdentifier: MessageCollectionCell.reuseID)
        collectionView.register(DateChipCell.self, forCellWithReuseIdentifier: DateChipCell.reuseID)
        collectionView.register(UnreadSeparatorCell.self, forCellWithReuseIdentifier: UnreadSeparatorCell.reuseID)
        collectionView.register(SystemMessageCell.self, forCellWithReuseIdentifier: SystemMessageCell.reuseID)

        diffable = UICollectionViewDiffableDataSource<ChatSection, ChatRow>(collectionView: collectionView) { [weak self] collectionView, indexPath, row in
            guard let self else { return UICollectionViewCell() }
            switch row {
            case .date(let date):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DateChipCell.reuseID, for: indexPath) as! DateChipCell
                cell.configure(date: date, theme: self.theme)
                return cell
            case .unread:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: UnreadSeparatorCell.reuseID, for: indexPath) as! UnreadSeparatorCell
                cell.configure(theme: self.theme)
                return cell
            case .message(let message, let decoration):
                if case .system(let text) = message.kind {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SystemMessageCell.reuseID, for: indexPath) as! SystemMessageCell
                    cell.configure(text: text, theme: self.theme)
                    return cell
                }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MessageCollectionCell.reuseID, for: indexPath) as! MessageCollectionCell
                cell.configure(
                    message: message,
                    decoration: decoration,
                    participant: self.dataSource.participant(id: message.senderID),
                    theme: self.theme,
                    width: collectionView.bounds.width,
                    isSelecting: self.isSelecting,
                    isSelected: self.selectedIDs.contains(message.id),
                    allowsReplySwipe: !self.isSelecting
                )
                cell.onReply = { [weak self] in self?.beginReply($0) }
                cell.onOpenURL = { [weak self] in self?.actions.onOpenURL?($0) ?? UIApplication.shared.open($0) }
                cell.onOpenMedia = { [weak self] in self?.openMediaPager(startingAt: $0) }
                return cell
            }
        }
    }

    private func configureHeader() {
        headerView.onBack = { [weak self] in self?.actions.onBack?() }
        headerView.onCancelSelection = { [weak self] in self?.exitSelection() }
        headerView.onTitleTap = { [weak self] in self?.actions.onHeaderTap?() }
        headerView.onVideo = { [weak self] in self?.actions.onVideo?() }
        headerView.onCall = { [weak self] in self?.actions.onCall?() }
        headerView.apply(content: header, theme: theme)
    }

    private func configureComposer() {
        composer.delegate = self
        selectionToolbar.onForward = { [weak self] in self?.forwardSelected() }
        selectionToolbar.onDelete = { [weak self] in self?.deleteSelected() }
        attachmentSheet.onAction = { [weak self] in self?.handleAttachment($0) }
        attachmentSheet.onPickAsset = { [weak self] in self?.stageAsset($0) }
        composer.textView.inputView = nil
        composer.bindDismissPassthrough(to: collectionView.panGestureRecognizer)
    }

    private func bindKeyboardIfNeeded() {
        guard !didBindKeyboard else { return }
        didBindKeyboard = true
        keyboardTracker.listComposerGap = theme.layout.listComposerGap
        bottomChrome.setContentHuggingPriority(.required, for: .vertical)
        bottomChrome.setContentCompressionResistancePriority(.required, for: .vertical)
        keyboardTracker.onApplied = { [weak self] _, layoutBottom, flushingLayout in
            self?.applyComposerLayoutPadding(layoutBottom)
            // `flushingLayout` is only true outside collection callbacks (crash contract).
            if flushingLayout { self?.pinToBottomIfNeeded() }
        }
        keyboardTracker.attach(
            host: view,
            composer: bottomChrome,
            collectionView: collectionView
        )
    }

    private func updateDismissPanEnabled() {
        let locked = voice.state != .idle || isSheetPresented
        keyboardTracker.dismissPanEnabled = !locked
        composer.isDismissPassthroughEnabled = !locked
        composer.setRecordingChromeLocked(voice.state != .idle)
    }

    private func configureVoice() {
        voice.onLevel = { [weak self] level, duration in
            self?.voiceOverlay.pushLevel(level, duration: duration)
        }
        voice.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .idle: self.voiceOverlay.hide()
            case .recording: self.voiceOverlay.showRecording()
            case .locked:
                self.voiceOverlay.showLocked()
                self.voiceOverlay.setPaused(false)
            case .paused:
                self.voiceOverlay.showLocked()
                self.voiceOverlay.setPaused(true)
            }
            self.updateDismissPanEnabled()
        }
        voiceOverlay.onCancel = { [weak self] in self?.voice.cancel() }
        voiceOverlay.onLock = { [weak self] in self?.voice.lock() }
        voiceOverlay.onPause = { [weak self] in
            if self?.voice.state == .paused { self?.voice.resume() } else { self?.voice.pause() }
        }
        voiceOverlay.onPreview = { [weak self] in
            guard let self else { return }
            let playing = self.voice.togglePreview()
            self.voiceOverlay.setPreviewing(playing)
        }
        voiceOverlay.onSend = { [weak self] in self?.sendVoice() }
    }

    private func applyChrome() {
        wallpaper.backgroundColor = DoodleWallpaper.color(base: theme.colors.wallpaper)
        view.backgroundColor = theme.colors.wallpaper
        headerView.apply(content: header, theme: theme)
        if isSelecting {
            headerView.applySelectionCount(selectedIDs.count)
        }
        composer.apply(
            theme: theme,
            sendable: isSendable,
            sheetPresented: composer.textView.inputView != nil,
            reply: replyTarget
        )
        selectionToolbar.apply(theme: theme, selectedCount: selectedIDs.count)
        attachmentSheet.apply(theme: theme)
        voiceOverlay.apply(theme: theme)
        fab.backgroundColor = theme.colors.fabFill
        fab.tintColor = theme.colors.fabIcon
        fab.layer.cornerRadius = 22
        chatLayout.settings.interItemSpacing = theme.layout.groupingSequenceSpacing
        chatLayout.settings.additionalInsets = UIEdgeInsets(
            top: theme.layout.listComposerGap,
            left: 0,
            bottom: ComposerKeyboardTracker.layoutBottomPadding(
                composerHeight: bottomChrome.bounds.height,
                listComposerGap: theme.layout.listComposerGap
            ),
            right: 0
        )
        keyboardTracker.listComposerGap = theme.layout.listComposerGap
        collectionView.reloadData()
    }

    private var isSendable: Bool {
        !composer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !staged.isEmpty
    }

    private func updateHeaderHeight() {
        let bar: CGFloat = (header.subtitle != nil || header.isTyping)
            ? theme.layout.headerHeightTall
            : theme.layout.headerHeightCompact
        headerHeightConstraint?.constant = view.safeAreaInsets.top + bar
    }

    private func updateTopInset() {
        let top = headerView.bounds.height
        if collectionView.contentInset.top != top {
            collectionView.contentInset.top = top
            collectionView.verticalScrollIndicatorInsets.top = top
        }
    }

    /// ChatLayout lays the last item using `additionalInsets.bottom` as well as
    /// `contentInset`. Keep that padding at composer height + gap.
    private func applyComposerLayoutPadding(_ bottom: CGFloat) {
        var insets = chatLayout.settings.additionalInsets
        guard abs(insets.bottom - bottom) > 0.5 else { return }
        insets.bottom = bottom
        chatLayout.settings.additionalInsets = insets
    }

    private func pinToBottomIfNeeded() {
        guard isNearBottom else { return }
        scrollToBottom(animated: false)
    }

    private func scrollToBottom(animated: Bool) {
        guard !rows.isEmpty else { return }
        let index = IndexPath(item: rows.count - 1, section: 0)
        collectionView.layoutIfNeeded()
        let snapshot = ChatLayoutPositionSnapshot(indexPath: index, edge: .bottom, offset: 0)
        if animated {
            UIView.animate(withDuration: 0.22) {
                self.chatLayout.restoreContentOffset(with: snapshot)
            }
        } else {
            chatLayout.restoreContentOffset(with: snapshot)
        }
        isNearBottom = true
        updateFAB()
    }

    private func updateFAB() {
        let inset = collectionView.adjustedContentInset
        let visibleBottom = collectionView.contentOffset.y + collectionView.bounds.height - inset.bottom
        let distance = collectionView.contentSize.height - visibleBottom
        let show = distance > 120 && collectionView.contentSize.height > collectionView.bounds.height
        fab.isHidden = !show
    }

    @objc private func tapFAB() { scrollToBottom(animated: true) }

    private func insertHostMessage(_ message: Message?) {
        insertHostMessages(message.map { [$0] })
    }

    private func insertHostMessages(_ messages: [Message]?) {
        guard let messages, !messages.isEmpty else { return }
        var next = snapshot
        next.messages.append(contentsOf: messages)
        apply(next, animatingDifferences: true)
    }

    private func beginReply(_ message: Message) {
        replyTarget = message
        actions.onReply?(message)
        composer.apply(theme: theme, sendable: isSendable, sheetPresented: isSheetPresented, reply: message)
        presentKeyboard()
        keyboardTracker.syncListInsets()
    }

    private var isSheetPresented: Bool {
        composer.textView.inputView === attachmentSheet
    }

    private func presentSheet() {
        attachmentSheet.apply(theme: theme)
        attachmentSheet.reloadRecents()
        composer.textView.inputView = attachmentSheet
        composer.textView.reloadInputViews()
        if !composer.textView.isFirstResponder {
            composer.textView.becomeFirstResponder()
        }
        composer.apply(theme: theme, sendable: isSendable, sheetPresented: true, reply: replyTarget)
        updateDismissPanEnabled()
    }

    private func showKeyboardFromSheet() {
        composer.textView.inputView = nil
        composer.textView.reloadInputViews()
        composer.textView.becomeFirstResponder()
        composer.apply(theme: theme, sendable: isSendable, sheetPresented: false, reply: replyTarget)
        updateDismissPanEnabled()
    }

    private func sendVoice() {
        guard let take = voice.finish() else { return }
        let quote = replyTarget
        replyTarget = nil
        composer.apply(theme: theme, sendable: isSendable, sheetPresented: isSheetPresented, reply: nil)
        insertHostMessage(actions.onSendVoice?(take.url, take.duration, take.waveform, quote))
        scrollToBottom(animated: true)
    }

    private func handleAttachment(_ action: AttachmentAction) {
        actions.onAttachmentAction?(action)
        switch action {
        case .photos:
            presentPicker()
        case .camera:
            presentCamera()
        case .location:
            if let coordinate = actions.onRequestLocation?() {
                stage(.init(kind: .location(latitude: coordinate.latitude, longitude: coordinate.longitude, label: nil)))
            }
        case .contact:
            let picker = CNContactPickerViewController()
            picker.delegate = self
            present(picker, animated: true)
        case .document:
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            picker.delegate = self
            present(picker, animated: true)
        case .poll, .event, .aiImages:
            break
        }
    }

    private func presentPicker() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        let used = approvalController?.session.items.count ?? 0
        let remaining = max(0, theme.layout.maxAttachmentsPerSend - used)
        if remaining == 0 {
            if let approval = approvalController {
                approval.showOverLimitToast()
            } else {
                BimbelToast.show(
                    EditSession.overLimitMessage(limit: theme.layout.maxAttachmentsPerSend),
                    in: view,
                    theme: theme
                )
            }
            return
        }
        config.selectionLimit = remaining
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        (approvalController ?? self).present(picker, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentApproval(admitting incoming: [EditSession.Item]) {
        guard !incoming.isEmpty || approvalController != nil else { return }
        if let approval = approvalController {
            _ = approval.admit(incoming)
            return
        }
        var session = EditSession()
        let result = session.admit(incoming, limit: theme.layout.maxAttachmentsPerSend)
        if result.rejected > 0 {
            BimbelToast.show(
                EditSession.overLimitMessage(limit: theme.layout.maxAttachmentsPerSend),
                in: view,
                theme: theme
            )
        }
        guard !session.items.isEmpty else { return }
        let approval = MediaApprovalViewController(session: session, theme: theme)
        approval.onSend = { [weak self] session in
            self?.sendApproved(session)
        }
        approval.onAddMore = { [weak self] _ in
            self?.presentPicker()
        }
        approval.onCancel = { [weak self] in
            self?.approvalController = nil
        }
        let nav = UINavigationController(rootViewController: approval)
        nav.modalPresentationStyle = .fullScreen
        approvalController = approval
        present(nav, animated: true)
    }

    private func sendApproved(_ session: EditSession) {
        MediaRender.export(session, theme: theme) { [weak self] media in
            guard let self else { return }
            let caption = session.caption.trimmingCharacters(in: .whitespacesAndNewlines)
            let captionOrNil = caption.isEmpty ? nil : caption
            if self.actions.onSendMedia != nil {
                self.insertHostMessages(self.actions.onSendMedia?(media, captionOrNil))
            } else {
                self.insertHostMessage(self.actions.onSendAttachments?(media.map { $0.asStagedAttachment() }))
                if let captionOrNil {
                    self.insertHostMessage(self.actions.onSendText?(captionOrNil))
                }
            }
            self.approvalController?.dismiss(animated: true)
            self.approvalController = nil
            self.scrollToBottom(animated: true)
        }
    }

    private func stage(_ attachment: StagedAttachment) {
        staged.append(attachment)
        composer.apply(theme: theme, sendable: true, sheetPresented: isSheetPresented, reply: replyTarget)
    }

    private func stageAsset(_ asset: PHAsset) {
        MediaIntakeLoader.item(from: asset) { [weak self] item in
            guard let item else { return }
            self?.presentApproval(admitting: [item])
        }
    }

    private func sendComposer() {
        if !staged.isEmpty {
            let payload = staged
            staged.removeAll()
            insertHostMessage(actions.onSendAttachments?(payload))
        }
        let text = composer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            composer.text = ""
            insertHostMessage(actions.onSendText?(text))
        }
        replyTarget = nil
        composer.apply(theme: theme, sendable: false, sheetPresented: isSheetPresented, reply: nil)
        scrollToBottom(animated: true)
    }

    private func loadOlderIfNeeded() {
        guard !isLoadingOlder, collectionView.contentOffset.y < -collectionView.adjustedContentInset.top + 40 else { return }
        isLoadingOlder = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let older = try await self.dataSource.loadOlder(in: self.conversationID)
                self.apply(older, animatingDifferences: false)
            } catch {
                // Host can surface errors; the list stays put.
            }
            self.isLoadingOlder = false
        }
    }
}

extension ConversationViewController: ChatLayoutDelegate {
    public func alignmentForItem(_ chatLayout: CollectionViewChatLayout, at indexPath: IndexPath) -> ChatItemAlignment {
        guard indexPath.item < rows.count else { return .fullWidth }
        switch rows[indexPath.item] {
        case .date, .unread:
            return .center
        case .message(let message, _):
            if case .system = message.kind { return .center }
            return message.isOutgoing ? .trailing : .leading
        }
    }

    public func sizeForItem(_ chatLayout: CollectionViewChatLayout, at indexPath: IndexPath) -> ItemSize {
        .auto
    }

    public func interItemSpacing(_ chatLayout: CollectionViewChatLayout, after indexPath: IndexPath) -> CGFloat? {
        guard indexPath.item + 1 < rows.count else { return theme.layout.groupingSequenceSpacing }
        let current = rows[indexPath.item]
        let next = rows[indexPath.item + 1]
        guard case .message(let a, let da) = current, case .message(let b, let db) = next else {
            return theme.layout.groupingSequenceSpacing
        }
        if da.mediaStack.joinsBottom || db.mediaStack.joinsTop {
            return theme.layout.mediaStackGap
        }
        if da.cluster.isLastInCluster || a.senderID != b.senderID {
            return theme.layout.groupingSequenceSpacing
        }
        return theme.layout.groupingInnerSpacing
    }
}

extension ConversationViewController: UICollectionViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !keyboardTracker.isMutatingInsets {
            isNearBottom = ComposerKeyboardTracker.isNearBottom(
                contentHeight: scrollView.contentSize.height,
                offsetY: scrollView.contentOffset.y,
                boundsHeight: scrollView.bounds.height,
                adjustedBottomInset: scrollView.adjustedContentInset.bottom
            )
        }
        updateFAB()
        loadOlderIfNeeded()
        keyboardTracker.syncListInsets()
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard !isSelecting else { return nil }
        guard indexPath.item < rows.count, case .message(let message, _) = rows[indexPath.item] else { return nil }
        if case .system = message.kind { return nil }
        // Targeted bubble preview only. `previewProvider` stays nil so UIKit
        // does not present a fullscreen preview controller. Do not implement
        // `willPerformPreviewActionForMenuWith` — tap on media opens the pager.
        return UIContextMenuConfiguration(identifier: message.id as NSString, previewProvider: nil) { [weak self] _ in
            self?.menu(for: message)
        }
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        targetedPreview(for: configuration)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        targetedPreview(for: configuration)
    }

    private func openMediaPager(startingAt message: Message) {
        guard !isSelecting, ConversationMessageMenu.isMedia(message) else { return }
        var items = MediaPagerItems.collect(snapshot.messages)
        if items.contains(where: { $0.id == message.id }) == false {
            items.insert(message, at: 0)
        }
        let pager = MediaPagerViewController(
            items: items,
            startID: message.id,
            theme: theme,
            onSave: { [weak self] in self?.actions.onSaveMedia?($0) },
            onForward: { [weak self] in self?.actions.onForward?([$0]) }
        )
        present(pager, animated: true)
    }

    private func targetedPreview(for configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let id = configuration.identifier as? String,
              let index = rows.firstIndex(where: {
                  if case .message(let message, _) = $0 { return message.id == id }
                  return false
              }),
              let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? MessageCollectionCell
        else { return nil }
        let params = UIPreviewParameters()
        params.backgroundColor = .clear
        params.visiblePath = cell.previewVisiblePath
        return UITargetedPreview(view: cell.previewTarget, parameters: params)
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard isSelecting,
              indexPath.item < rows.count,
              case .message(let message, _) = rows[indexPath.item]
        else { return }
        if case .system = message.kind { return }
        toggleSelection(message.id)
    }

    private func menu(for message: Message) -> UIMenu {
        let rail = UIMenu(title: "", options: .displayInline, children: reactionPalette.map { emoji in
            UIAction(title: emoji) { [weak self] _ in self?.actions.onReaction?(message, emoji) }
        })
        let actions = ConversationMessageMenu.items(
            for: message,
            allowsEdit: self.actions.allowsEdit(message)
        ).map { item in
            UIAction(
                title: item.title,
                image: item.lineImage,
                attributes: item.isDestructive ? .destructive : []
            ) { [weak self] _ in
                self?.performMenu(item, on: message)
            }
        }
        return UIMenu(children: [rail] + actions)
    }

    private func performMenu(_ item: ConversationMessageMenuItem, on message: Message) {
        switch item {
        case .reply:
            beginReply(message)
        case .copy:
            if case .text(let body, _) = message.kind {
                UIPasteboard.general.string = body
            }
        case .save:
            actions.onSaveMedia?(message)
        case .forward:
            actions.onForward?([message])
        case .delete:
            actions.onDeleteMessages?([message])
        case .select:
            enterSelection(seed: message.id)
        case .edit:
            actions.onEdit?(message)
            if case .text(let body, _) = message.kind {
                composer.text = body
                presentKeyboard()
            }
        }
    }

    private func enterSelection(seed: MessageID) {
        isSelecting = true
        selectedIDs = [seed]
        composer.textView.resignFirstResponder()
        composer.isHidden = true
        selectionToolbar.isHidden = false
        refreshSelectionChrome()
        collectionView.reloadData()
        keyboardTracker.syncListInsets(flushingLayout: true)
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs = []
        composer.isHidden = false
        selectionToolbar.isHidden = true
        headerView.applySelectionCount(nil)
        refreshSelectionChrome()
        collectionView.reloadData()
        keyboardTracker.syncListInsets(flushingLayout: true)
    }

    private func toggleSelection(_ id: MessageID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
        refreshSelectionChrome()
        collectionView.reloadData()
    }

    private func selectedMessages() -> [Message] {
        snapshot.messages.filter { selectedIDs.contains($0.id) }
    }

    private func forwardSelected() {
        let messages = selectedMessages()
        guard !messages.isEmpty else { return }
        actions.onForward?(messages)
        exitSelection()
    }

    private func deleteSelected() {
        let messages = selectedMessages()
        guard !messages.isEmpty else { return }
        actions.onDeleteMessages?(messages)
        exitSelection()
    }

    private func refreshSelectionChrome() {
        selectionToolbar.apply(theme: theme, selectedCount: selectedIDs.count)
        headerView.applySelectionCount(isSelecting ? selectedIDs.count : nil)
    }
}

extension ConversationViewController: ComposerViewDelegate {
    func composerDidChangeText(_ composer: ComposerView) {
        composer.apply(theme: theme, sendable: isSendable, sheetPresented: isSheetPresented, reply: replyTarget)
        keyboardTracker.syncListInsets(flushingLayout: true)
    }

    func composerDidTapPlus(_ composer: ComposerView) {
        presentSheet()
    }

    func composerDidLongPressPlus(_ composer: ComposerView) {
        presentPicker()
    }

    func composerDidTapKeyboard(_ composer: ComposerView) {
        showKeyboardFromSheet()
    }

    func composerDidTapSticker(_ composer: ComposerView) {
        composer.textView.becomeFirstResponder()
    }

    func composerDidTapCamera(_ composer: ComposerView) {
        presentCamera()
    }

    func composerDidTapSend(_ composer: ComposerView) {
        sendComposer()
    }

    func composerDidBeginMicHold(_ composer: ComposerView) {
        voice.begin()
    }

    func composerDidUpdateMicHold(_ composer: ComposerView, translation: CGPoint) {
        let cancelAt = theme.layout.voiceCancelTranslation
        let lockAt = theme.layout.voiceLockTranslation
        voiceOverlay.applyHoldProgress(translation, cancelAt: cancelAt, lockAt: lockAt)
        // Lock on crossing the well. Do not discard during the slide — the
        // cancel hint must stay up and turn systemRed past 72pt.
        if voice.update(translation: translation, cancelAt: cancelAt, lockAt: lockAt) == .lock {
            voice.lock()
        }
    }

    func composerDidEndMicHold(_ composer: ComposerView, translation: CGPoint) {
        switch voice.state {
        case .recording:
            if VoiceGesture.outcome(
                translation: translation,
                cancelAt: theme.layout.voiceCancelTranslation,
                lockAt: theme.layout.voiceLockTranslation
            ) == .cancel {
                voice.cancel()
                restoreIdleComposer()
            } else {
                sendVoice()
            }
        case .locked, .paused, .idle:
            break
        }
    }

    /// Cancel-past-72pt (and any idle transition): hide the hold bar and
    /// put Plus / Message / Camera / mic back. Lock chrome is unchanged.
    private func restoreIdleComposer() {
        voiceOverlay.hide()
        updateDismissPanEnabled()
        composer.apply(
            theme: theme,
            sendable: isSendable,
            sheetPresented: isSheetPresented,
            reply: replyTarget
        )
    }

    func composerDidCancelReply(_ composer: ComposerView) {
        replyTarget = nil
        composer.apply(theme: theme, sendable: isSendable, sheetPresented: isSheetPresented, reply: nil)
    }

    func composerDidChangeHeight(_ composer: ComposerView) {
        keyboardTracker.syncListInsets(flushingLayout: true)
    }

    func composerShouldBeginEditing(_ composer: ComposerView) -> Bool {
        true
    }

    func composerDidEndEditing(_ composer: ComposerView) {
        keyboardTracker.syncListInsets(flushingLayout: true)
    }
}

extension ConversationViewController: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }
        MediaIntakeLoader.items(from: results) { [weak self] items in
            self?.presentApproval(admitting: items)
        }
    }
}

extension ConversationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        // Decode on this MainActor method so the dismiss completion does not
        // capture non-Sendable `info` (Swift 6.1).
        let item = MediaIntakeLoader.item(fromCamera: info)
        picker.dismiss(animated: true)
        if let item {
            presentApproval(admitting: [item])
        }
    }
}

extension ConversationViewController: @preconcurrency CNContactPickerDelegate {
    public func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        picker.dismiss(animated: true)
    }

    public func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        picker.dismiss(animated: true)
        let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "Contact"
        stage(.init(kind: .contact(displayName: name)))
    }
}

extension ConversationViewController: UIDocumentPickerDelegate {
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        stage(.init(kind: .document(Document(name: url.lastPathComponent, byteCount: size, fileURL: url))))
    }
}
