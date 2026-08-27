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

    private let wallpaper = UIView()
    private let chatLayout = CollectionViewChatLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: chatLayout)
    private var diffable: UICollectionViewDiffableDataSource<ChatSection, ChatRow>!
    private let headerView = ConversationHeaderView()
    private let composer = ComposerView()
    private let accessoryContainer = ComposerAccessoryContainer()
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
    private var isComposerInAccessory = false
    private var dockConstraints: [NSLayoutConstraint] = []
    private var fabAboveComposer: NSLayoutConstraint?
    private var fabAboveKeyboard: NSLayoutConstraint?
    private var isLoadingOlder = false
    private var isNearBottom = true
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

    public override var canBecomeFirstResponder: Bool { true }

    public override var inputAccessoryView: UIView? {
        isComposerInAccessory ? accessoryContainer : nil
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        NavigationChrome.hideSystemBar(in: self, animated: false)
        view.backgroundColor = theme.colors.wallpaper
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
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
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        composer.textView.resignFirstResponder()
        dockComposerInHost()
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
        rows = MessageGrouping.rows(from: snapshot)
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

    // MARK: - Hierarchy

    private func configureHierarchy() {
        wallpaper.backgroundColor = DoodleWallpaper.color(base: theme.colors.wallpaper)
        view.addSubview(wallpaper)
        wallpaper.bimbelPinToEdges(of: view)

        chatLayout.delegate = self
        chatLayout.keepContentOffsetAtBottomOnBatchUpdates = true
        chatLayout.keepContentAtBottomOfVisibleArea = true
        chatLayout.settings.estimatedItemSize = CGSize(width: UIScreen.main.bounds.width, height: 84)
        chatLayout.settings.interItemSpacing = theme.layout.sequenceGap
        chatLayout.settings.additionalInsets = UIEdgeInsets(
            top: theme.layout.composerGap,
            left: 0,
            bottom: ComposerKeyboardTracker.layoutBottomPadding(
                composerHeight: composer.bounds.height,
                breathing: theme.layout.composerGap
            ),
            right: 0
        )

        collectionView.backgroundColor = .clear
        collectionView.isOpaque = false
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .interactiveWithAccessory
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

        view.addSubview(composer)
        composer.translatesAutoresizingMaskIntoConstraints = false
        dockConstraints = [
            composer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ]
        NSLayoutConstraint.activate(dockConstraints)

        view.addSubview(voiceOverlay)
        voiceOverlay.bimbelPinToEdges(of: view)

        fab.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        fab.addTarget(self, action: #selector(tapFAB), for: .touchUpInside)
        fab.layer.shadowOpacity = 0.18
        fab.layer.shadowRadius = 8
        fab.layer.shadowOffset = CGSize(width: 0, height: 2)
        fab.isHidden = true
        view.addSubview(fab)
        fab.translatesAutoresizingMaskIntoConstraints = false
        fabAboveComposer = fab.bottomAnchor.constraint(equalTo: composer.topAnchor, constant: -10)
        fabAboveKeyboard = fab.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor,
            constant: -10
        )
        NSLayoutConstraint.activate([
            fab.widthAnchor.constraint(equalToConstant: 44),
            fab.heightAnchor.constraint(equalToConstant: 44),
            fab.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            fabAboveComposer!
        ])
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
                    width: collectionView.bounds.width
                )
                cell.onReply = { [weak self] in self?.beginReply($0) }
                cell.onOpenURL = { [weak self] in self?.actions.onOpenURL?($0) ?? UIApplication.shared.open($0) }
                return cell
            }
        }
    }

    private func configureHeader() {
        headerView.onBack = { [weak self] in self?.actions.onBack?() }
        headerView.onTitleTap = { [weak self] in self?.actions.onHeaderTap?() }
        headerView.onVideo = { [weak self] in self?.actions.onVideo?() }
        headerView.onCall = { [weak self] in self?.actions.onCall?() }
        headerView.apply(content: header, theme: theme)
    }

    private func configureComposer() {
        composer.delegate = self
        attachmentSheet.onAction = { [weak self] in self?.handleAttachment($0) }
        attachmentSheet.onPickAsset = { [weak self] in self?.stageAsset($0) }
        composer.textView.inputView = nil
        composer.textView.accessoryContainer = nil
    }

    private func bindKeyboardIfNeeded() {
        guard !didBindKeyboard else { return }
        didBindKeyboard = true
        keyboardTracker.bottomBreathingRoom = theme.layout.composerGap
        composer.setContentHuggingPriority(.required, for: .vertical)
        composer.setContentCompressionResistancePriority(.required, for: .vertical)
        keyboardTracker.onApplied = { [weak self] _, layoutBottom, flushingLayout in
            self?.applyComposerLayoutPadding(layoutBottom)
            // `flushingLayout` is only true outside collection callbacks (crash contract).
            if flushingLayout { self?.pinToBottomIfNeeded() }
        }
        keyboardTracker.attach(host: view, composer: composer, collectionView: collectionView)
        dockComposerInHost()
    }

    private func moveComposerToAccessory() {
        guard !isComposerInAccessory else {
            accessoryContainer.invalidateIntrinsicContentSize()
            return
        }
        NSLayoutConstraint.deactivate(dockConstraints)
        fabAboveComposer?.isActive = false
        fabAboveKeyboard?.isActive = true
        accessoryContainer.embed(composer)
        composer.textView.accessoryContainer = accessoryContainer
        isComposerInAccessory = true
        keyboardTracker.isComposerInAccessory = true
        if composer.textView.isFirstResponder {
            composer.textView.reloadInputViews()
        }
        keyboardTracker.syncListInsets(flushingLayout: true)
    }

    private func dockComposerInHost() {
        guard composer.superview !== view else {
            keyboardTracker.isComposerInAccessory = false
            isComposerInAccessory = false
            composer.textView.accessoryContainer = nil
            return
        }
        composer.removeFromSuperview()
        view.insertSubview(composer, belowSubview: voiceOverlay)
        composer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(dockConstraints)
        fabAboveKeyboard?.isActive = false
        fabAboveComposer?.isActive = true
        composer.textView.accessoryContainer = nil
        isComposerInAccessory = false
        keyboardTracker.isComposerInAccessory = false
        if isFirstResponder {
            reloadInputViews()
        }
        keyboardTracker.syncListInsets(flushingLayout: true)
    }

    private func updateDismissPanEnabled() {
        let locked = voice.state != .idle || isSheetPresented
        keyboardTracker.dismissPanEnabled = !locked
        composer.isDismissPassthroughEnabled = !locked
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
            case .locked, .paused: self.voiceOverlay.showLocked()
            }
            self.updateDismissPanEnabled()
        }
        voiceOverlay.onCancel = { [weak self] in self?.voice.cancel() }
        voiceOverlay.onLock = { [weak self] in self?.voice.lock() }
        voiceOverlay.onPause = { [weak self] in
            if self?.voice.state == .paused { self?.voice.resume() } else { self?.voice.pause() }
        }
        voiceOverlay.onSend = { [weak self] in self?.sendVoice() }
    }

    private func applyChrome() {
        wallpaper.backgroundColor = DoodleWallpaper.color(base: theme.colors.wallpaper)
        view.backgroundColor = theme.colors.wallpaper
        headerView.apply(content: header, theme: theme)
        composer.apply(
            theme: theme,
            sendable: isSendable,
            sheetPresented: composer.textView.inputView != nil,
            reply: replyTarget
        )
        attachmentSheet.apply(theme: theme)
        fab.backgroundColor = theme.colors.fabFill
        fab.tintColor = theme.colors.fabIcon
        fab.layer.cornerRadius = 22
        chatLayout.settings.interItemSpacing = theme.layout.sequenceGap
        chatLayout.settings.additionalInsets = UIEdgeInsets(
            top: theme.layout.composerGap,
            left: 0,
            bottom: ComposerKeyboardTracker.layoutBottomPadding(
                composerHeight: composer.bounds.height,
                breathing: theme.layout.composerGap
            ),
            right: 0
        )
        keyboardTracker.bottomBreathingRoom = theme.layout.composerGap
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
        guard let message else { return }
        var next = snapshot
        next.messages.append(message)
        apply(next, animatingDifferences: true)
    }

    private func beginReply(_ message: Message) {
        replyTarget = message
        actions.onReply?(message)
        composer.apply(theme: theme, sendable: isSendable, sheetPresented: isSheetPresented, reply: message)
        composer.textView.becomeFirstResponder()
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
        guard let url = voice.finish() else { return }
        insertHostMessage(actions.onSendVoice?(url))
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
        config.selectionLimit = 8
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    private func stage(_ attachment: StagedAttachment) {
        staged.append(attachment)
        composer.apply(theme: theme, sendable: true, sheetPresented: isSheetPresented, reply: replyTarget)
    }

    private func stageAsset(_ asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { [weak self] data, _, _, _ in
            guard let data else { return }
            self?.stage(.init(kind: .image(.data(data))))
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
        guard indexPath.item + 1 < rows.count else { return theme.layout.sequenceGap }
        let current = rows[indexPath.item]
        let next = rows[indexPath.item + 1]
        guard case .message(let a, let da) = current, case .message(let b, let db) = next else {
            return theme.layout.sequenceGap
        }
        if da.mediaStack.joinsBottom || db.mediaStack.joinsTop {
            return theme.layout.mediaStackGap
        }
        if da.cluster.isLastInCluster || a.senderID != b.senderID {
            return theme.layout.sequenceGap
        }
        return theme.layout.clusterGap
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
        guard indexPath.item < rows.count, case .message(let message, _) = rows[indexPath.item] else { return nil }
        if case .system = message.kind { return nil }
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
        return UITargetedPreview(view: cell.previewTarget, parameters: params)
    }

    private func menu(for message: Message) -> UIMenu {
        let rail = UIMenu(title: "", options: .displayInline, children: reactionPalette.map { emoji in
            UIAction(title: emoji) { [weak self] _ in self?.actions.onReaction?(message, emoji) }
        })
        var items: [UIMenuElement] = [rail]
        items.append(UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { [weak self] _ in
            self?.beginReply(message)
        })
        if case .text(let body, _) = message.kind {
            items.append(UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = body
            })
        }
        return UIMenu(children: items)
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
        switch voice.update(translation: translation) {
        case .cancel: voice.cancel()
        case .lock: voice.lock()
        case .send, .none: break
        }
    }

    func composerDidEndMicHold(_ composer: ComposerView, translation: CGPoint) {
        switch voice.state {
        case .recording:
            if translation.x < -80 {
                voice.cancel()
            } else {
                sendVoice()
            }
        case .locked, .paused, .idle:
            break
        }
    }

    func composerDidCancelReply(_ composer: ComposerView) {
        replyTarget = nil
        composer.apply(theme: theme, sendable: isSendable, sheetPresented: isSheetPresented, reply: nil)
    }

    func composerDidChangeHeight(_ composer: ComposerView) {
        accessoryContainer.invalidateIntrinsicContentSize()
        keyboardTracker.syncListInsets(flushingLayout: true)
    }

    func composerWillBeginEditing(_ composer: ComposerView) {
        moveComposerToAccessory()
    }

    func composerDidEndEditing(_ composer: ComposerView) {
        guard !composer.textView.isFirstResponder else { return }
        dockComposerInHost()
    }
}

extension ConversationViewController: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for result in results {
            let provider = result.itemProvider
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                    guard let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.86) else { return }
                    DispatchQueue.main.async {
                        self?.stage(.init(kind: .image(.data(data))))
                    }
                }
            }
        }
    }
}

extension ConversationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.86) {
            stage(.init(kind: .image(.data(data))))
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
