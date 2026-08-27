import Bimbel
import CoreLocation
import UIKit

/// Hosts `ConversationViewController` so coding agents can see a drop-in.
/// Tap the header title to switch Default ↔ Blue.
final class SampleHostViewController: UIViewController {
    private let store = FakeConversationDataSource()
    private var conversation: ConversationViewController!
    private var usingBlue = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        embed(theme: .default)
    }

    private func embed(theme: ConversationTheme) {
        if let conversation {
            conversation.willMove(toParent: nil)
            conversation.view.removeFromSuperview()
            conversation.removeFromParent()
        }
        let controller = ConversationViewController(
            conversationID: store.conversationID,
            dataSource: store,
            theme: theme,
            header: store.header(isTyping: store.isTyping),
            actions: actions()
        )
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.didMove(toParent: self)
        conversation = controller
    }

    private func actions() -> ConversationActions {
        ConversationActions(
            onBack: { [weak self] in
                self?.store.toggleTyping()
                self?.conversation.header = self?.store.header(isTyping: self?.store.isTyping ?? false)
                    ?? HeaderContent(title: "Ada")
            },
            onHeaderTap: { [weak self] in
                guard let self else { return }
                self.usingBlue.toggle()
                self.embed(theme: self.usingBlue ? .blue : .default)
            },
            onVideo: {},
            onCall: {},
            onSendText: { [weak self] text in
                self?.store.sendText(text)
            },
            onSendAttachments: { [weak self] attachments in
                self?.store.sendAttachments(attachments)
            },
            onSendVoice: { [weak self] url in
                self?.store.sendVoice(url)
            },
            onReply: { _ in },
            onReaction: { [weak self] message, emoji in
                self?.store.addReaction(to: message.id, emoji: emoji)
                if let snapshot = self?.store.snapshot(in: self?.store.conversationID ?? "") {
                    self?.conversation.apply(snapshot, animatingDifferences: true)
                }
            },
            onRequestLocation: {
                CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
            }
        )
    }
}
