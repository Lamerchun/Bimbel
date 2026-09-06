import Bimbel
import CoreLocation
import UIKit

/// Sample launches on the inbox. Tap a row to push `ConversationViewController`.
/// Tap the large inbox title (or a conversation title) to switch Default ↔ Blue.
final class SampleHostViewController: UIViewController {
    private let store = FakeConversationDataSource()
    private let nav = UINavigationController()
    private var inbox: InboxViewController!
    private var conversation: ConversationViewController?
    private var usingBlue = false

    private var theme: ConversationTheme { usingBlue ? .blue : .default }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        nav.setNavigationBarHidden(true, animated: false)
        nav.navigationBar.isTranslucent = true
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = nil
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.interactivePopGestureRecognizer?.isEnabled = true
        addChild(nav)
        view.addSubview(nav.view)
        nav.view.frame = view.bounds
        nav.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        nav.didMove(toParent: self)
        usingBlue = Self.launchThemeIsBlue
        showInbox()
        switch Self.shotName {
        case "ada":
            // Flag before push so viewDidAppear focuses the layout-guide-pinned composer.
            openConversation(store.adaID, animated: false, presentKeyboardOnAppear: true)
        case "design":
            openConversation("design", animated: false)
        case "inbox", nil:
            break
        default:
            break
        }
    }

    /// `BIMBEL_SHOT=inbox|ada|design` or `-BIMBEL_SHOT ada`.
    /// Ada stands the software keyboard; Design opens the group thread; inbox stays on the list.
    private static var shotName: String? {
        processValue("BIMBEL_SHOT")?.lowercased()
    }

    /// `BIMBEL_THEME=blue` or `-BIMBEL_THEME blue`. Anything else is Default.
    private static var launchThemeIsBlue: Bool {
        processValue("BIMBEL_THEME")?.lowercased() == "blue"
    }

    private static func processValue(_ name: String) -> String? {
        let env = ProcessInfo.processInfo.environment[name]
        if let env, !env.isEmpty { return env }
        let flag = "-\(name)"
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: flag) {
            let next = args.index(after: index)
            if next < args.endIndex { return args[next] }
        }
        return nil
    }

    private func showInbox() {
        let controller = InboxViewController(
            dataSource: store,
            theme: theme,
            title: String(localized: "Chats"),
            actions: inboxActions()
        )
        inbox = controller
        nav.setViewControllers([controller], animated: false)
        conversation = nil
    }

    private func openConversation(
        _ id: ConversationID,
        animated: Bool = true,
        presentKeyboardOnAppear: Bool = false
    ) {
        let controller = ConversationViewController(
            conversationID: id,
            dataSource: store,
            theme: theme,
            header: store.header(for: id),
            actions: conversationActions(for: id)
        )
        controller.presentsKeyboardOnAppear = presentKeyboardOnAppear
        conversation = controller
        nav.pushViewController(controller, animated: animated)
    }

    private func applyTheme() {
        inbox.theme = theme
        conversation?.theme = theme
        if let conversation {
            conversation.header = store.header(for: conversation.conversationID)
        }
    }

    private func refreshInbox() {
        // Covered inbox + Diffable apply is a SpringBoard death after voice
        // send/cancel. Refresh only when the thread is gone (`onBack`).
        guard conversation == nil else { return }
        inbox.apply(store.snapshot(), animatingDifferences: true)
    }

    private func inboxActions() -> InboxActions {
        InboxActions(
            onOpen: { [weak self] id in
                self?.store.markRead(id)
                self?.refreshInbox()
                self?.openConversation(id)
            },
            onToggleRead: { [weak self] id in
                self?.store.toggleRead(id)
                self?.refreshInbox()
            },
            onTogglePin: { [weak self] id in
                self?.store.togglePin(id)
                self?.refreshInbox()
            },
            onToggleMute: { [weak self] id in
                self?.store.toggleMute(id)
                self?.refreshInbox()
            },
            onDelete: { [weak self] id in
                self?.store.delete(id)
                self?.refreshInbox()
            },
            onTitleTap: { [weak self] in
                guard let self else { return }
                self.usingBlue.toggle()
                self.applyTheme()
            }
        )
    }

    private func conversationActions(for id: ConversationID) -> ConversationActions {
        ConversationActions(
            onBack: { [weak self] in
                self?.nav.popViewController(animated: true)
                self?.conversation = nil
                self?.refreshInbox()
            },
            onHeaderTap: { [weak self] in
                guard let self else { return }
                self.usingBlue.toggle()
                self.applyTheme()
            },
            onVideo: {},
            onCall: {},
            onSendText: { [weak self] text in
                guard let self else { return nil }
                let message = self.store.sendText(text, in: id)
                self.refreshInbox()
                return message
            },
            onSendAttachments: { [weak self] attachments in
                guard let self else { return nil }
                let message = self.store.sendAttachments(attachments, in: id)
                self.refreshInbox()
                return message
            },
            onSendMedia: { [weak self] media, caption in
                guard let self else { return nil }
                let messages = self.store.sendMedia(media, caption: caption, in: id)
                self.refreshInbox()
                return messages
            },
            onSendVoice: { [weak self] url, duration, waveform, quote in
                guard let self else { return nil }
                // Do not `refreshInbox()` here. The inbox is covered; applying
                // it from hold-release crashed in `reloadVisible` (SpringBoard).
                // `onBack` already refreshes the list.
                return self.store.sendVoice(
                    url,
                    duration: duration,
                    waveform: waveform,
                    quote: quote,
                    in: id
                )
            },
            onReply: { _ in },
            onReaction: { [weak self] message, emoji in
                guard let self else { return }
                self.store.addReaction(to: message.id, in: id, emoji: emoji)
                self.conversation?.apply(self.store.snapshot(in: id), animatingDifferences: true)
            },
            onForward: { _ in },
            onDeleteMessages: { [weak self] messages in
                guard let self else { return }
                self.store.deleteMessages(messages, in: id)
                self.conversation?.apply(self.store.snapshot(in: id), animatingDifferences: true)
                self.refreshInbox()
            },
            onSaveMedia: { message in
                switch message.kind {
                case .image(let media), .video(let media):
                    if case .data(let data) = media.source, let image = UIImage(data: data) {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }
                default:
                    break
                }
            },
            canEdit: { $0.isOutgoing },
            onEdit: { _ in },
            onRequestLocation: {
                CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
            }
        )
    }
}
