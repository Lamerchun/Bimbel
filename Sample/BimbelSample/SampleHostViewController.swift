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
        showInbox()
        if Self.shotName == "ada" {
            // Flag before push so viewDidAppear reparents, then focuses.
            openConversation(store.adaID, animated: false, presentKeyboardOnAppear: true)
        }
    }

    /// `BIMBEL_SHOT=ada` or `-BIMBEL_SHOT ada`. Opens Ada and stands the software keyboard.
    private static var shotName: String? {
        let env = ProcessInfo.processInfo.environment["BIMBEL_SHOT"]
        if let env, !env.isEmpty { return env }
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-BIMBEL_SHOT") {
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
        inbox.apply(store.snapshot(), animatingDifferences: true)
    }

    private func inboxActions() -> InboxActions {
        InboxActions(
            onOpen: { [weak self] id in
                self?.store.markRead(id)
                self?.refreshInbox()
                self?.openConversation(id)
            },
            onPin: { [weak self] id in
                self?.store.togglePin(id)
                self?.refreshInbox()
            },
            onMute: { [weak self] id in
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
            onSendVoice: { [weak self] url in
                guard let self else { return nil }
                let message = self.store.sendVoice(url, in: id)
                self.refreshInbox()
                return message
            },
            onReply: { _ in },
            onReaction: { [weak self] message, emoji in
                guard let self else { return }
                self.store.addReaction(to: message.id, in: id, emoji: emoji)
                self.conversation?.apply(self.store.snapshot(in: id), animatingDifferences: true)
            },
            onRequestLocation: {
                CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
            }
        )
    }
}
