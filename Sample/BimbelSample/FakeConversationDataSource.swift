import Bimbel
import UIKit

/// In-memory data source. No network. The package never mints IDs — this host does.
@MainActor
final class FakeConversationDataSource: ConversationDataSource {
    let conversationID: ConversationID = "sample-thread"
    let me: UserID = "me"
    let them: UserID = "wbi"
    private(set) var isTyping = false
    private var messages: [Message] = []
    private var olderExhausted = false

    init() {
        messages = Self.seed(me: me, them: them)
    }

    func snapshot(in conversationID: ConversationID) -> ConversationSnapshot {
        ConversationSnapshot(
            conversationID: conversationID,
            messages: messages,
            firstUnreadID: messages.first(where: { $0.id == "m-21" })?.id
        )
    }

    func loadOlder(in conversationID: ConversationID) async throws -> ConversationSnapshot {
        try await Task.sleep(nanoseconds: 250_000_000)
        if !olderExhausted {
            olderExhausted = true
            let older = (0..<8).map { index in
                Message(
                    id: "old-\(index)",
                    senderID: index.isMultiple(of: 2) ? them : me,
                    sentAt: Date().addingTimeInterval(-86_400 * 3 - Double(8 - index) * 90),
                    kind: .text("Older line \(index + 1)", preview: nil),
                    isOutgoing: !index.isMultiple(of: 2)
                )
            }
            messages.insert(contentsOf: older, at: 0)
        }
        return snapshot(in: conversationID)
    }

    func participant(id: UserID) -> Participant? {
        switch id {
        case me:
            return Participant(id: me, displayName: "You", nameColorToken: "self")
        case them:
            return Participant(id: them, displayName: "Ada", avatar: .data(Self.glyphData(title: "A", color: .systemGreen)))
        default:
            return nil
        }
    }

    func header(isTyping: Bool) -> HeaderContent {
        HeaderContent(
            title: "Ada",
            subtitle: isTyping ? "tap name to switch theme" : "tap name to switch theme",
            avatar: .data(Self.glyphData(title: "A", color: .systemGreen)),
            unreadBadge: 4,
            showsVideo: true,
            showsCall: true,
            showsUnifiedCall: false,
            isTyping: isTyping
        )
    }

    func toggleTyping() {
        isTyping.toggle()
    }

    func sendText(_ text: String) -> Message {
        let message = Message(
            id: UUID().uuidString,
            senderID: me,
            sentAt: Date(),
            kind: .text(text, preview: nil),
            delivery: .sent,
            isOutgoing: true
        )
        messages.append(message)
        return message
    }

    func sendAttachments(_ attachments: [StagedAttachment]) -> Message {
        let kind: MessageKind
        if let first = attachments.first {
            switch first.kind {
            case .image(let source):
                kind = .image(Media(source: source, width: 800, height: 800))
            case .video(let source):
                kind = .video(Media(source: source, width: 800, height: 800, duration: 12))
            case .document(let document):
                kind = .document(document)
            case .location(_, _, let label):
                kind = .text(label ?? "Dropped pin", preview: nil)
            case .contact(let name):
                kind = .text(name, preview: nil)
            }
        } else {
            kind = .text("Attachment", preview: nil)
        }
        let message = Message(
            id: UUID().uuidString,
            senderID: me,
            sentAt: Date(),
            kind: kind,
            delivery: .sent,
            isOutgoing: true
        )
        messages.append(message)
        return message
    }

    func sendVoice(_ url: URL) -> Message {
        let message = Message(
            id: UUID().uuidString,
            senderID: me,
            sentAt: Date(),
            kind: .voice(Voice(duration: 4, waveform: [0.2, 0.6, 0.4, 0.9, 0.3, 0.7], fileURL: url)),
            delivery: .sent,
            isOutgoing: true
        )
        messages.append(message)
        return message
    }

    func addReaction(to id: MessageID, emoji: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        var reactions = messages[index].reactions
        if let existing = reactions.firstIndex(where: { $0.emoji == emoji }) {
            if !reactions[existing].userIDs.contains(me) {
                reactions[existing].userIDs.append(me)
            }
        } else {
            reactions.append(Reaction(emoji: emoji, userIDs: [me]))
        }
        messages[index].reactions = reactions
    }

    private static func seed(me: UserID, them: UserID) -> [Message] {
        let now = Date()
        func at(_ minutes: TimeInterval) -> Date { now.addingTimeInterval(-minutes * 60) }
        let logo = ImageSource.data(glyphData(title: "WBI", color: UIColor(red: 0.18, green: 0.72, blue: 0.47, alpha: 1)))
        let preview = LinkPreview(
            url: URL(string: "https://example.com/bimbel")!,
            title: "Bimbel conversation component",
            summary: "Drop-in iOS thread. Surface 1.",
            siteName: "example.com",
            thumbnail: logo
        )
        return [
            Message(id: "m-01", senderID: them, sentAt: at(1_440), kind: .system("Messages are end-to-end encrypted."), isOutgoing: false),
            Message(id: "m-02", senderID: them, sentAt: at(1_400), kind: .text("Hey — this is the sample thread.", preview: nil), isOutgoing: false),
            Message(id: "m-03", senderID: them, sentAt: at(1_399), kind: .text("Scroll for mixed kinds: text, image, link, voice, system.", preview: nil), isOutgoing: false),
            Message(id: "m-04", senderID: me, sentAt: at(1_200), kind: .text("Sending a photo next.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-05", senderID: me, sentAt: at(1_199), kind: .image(Media(source: logo, width: 800, height: 800)), delivery: .read, isOutgoing: true),
            Message(id: "m-06", senderID: me, sentAt: at(1_198), kind: .text("Docs live on example.com", preview: preview), delivery: .read, isOutgoing: true),
            Message(id: "m-07", senderID: me, sentAt: at(1_197), kind: .text("Stacked as one silhouette.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-08", senderID: them, sentAt: at(900), kind: .text("Incoming cluster starts here.", preview: nil), isOutgoing: false),
            Message(id: "m-09", senderID: them, sentAt: at(899), kind: .text("Avatar only on the last bubble.", preview: nil), isOutgoing: false),
            Message(id: "m-10", senderID: them, sentAt: at(898), kind: .voice(Voice(duration: 6, waveform: [0.2, 0.4, 0.8, 0.5, 0.9, 0.3, 0.6])), isOutgoing: false),
            Message(id: "m-11", senderID: me, sentAt: at(700), kind: .document(Document(name: "spec.pdf", byteCount: 240_000)), delivery: .delivered, isOutgoing: true),
            Message(id: "m-12", senderID: them, sentAt: at(500), kind: .system("The message timer was updated. New messages will disappear from this chat after 7 days."), isOutgoing: false),
            Message(id: "m-13", senderID: me, sentAt: at(120), kind: .text("Hold the mic to record. Slide left to cancel, up to lock.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-14", senderID: them, sentAt: at(90), kind: .text("Swipe a bubble right to reply. Long-press for reactions.", preview: nil), isOutgoing: false),
            Message(id: "m-15", senderID: them, sentAt: at(89), kind: .image(Media(source: logo, width: 640, height: 640, caption: "Logo")), isOutgoing: false),
            Message(id: "m-16", senderID: me, sentAt: at(60), kind: .text("Back chevron also toggles the typing subtitle in this sample.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-17", senderID: them, sentAt: at(45), kind: .text("Default theme is mint. Tap the title for the blue accent.", preview: nil), isOutgoing: false),
            Message(id: "m-18", senderID: me, sentAt: at(30), kind: .text("Composer is Zustand B — floating plus, pill, camera, mic.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-19", senderID: me, sentAt: at(20), kind: .voice(Voice(duration: 3, waveform: [0.3, 0.7, 0.4, 0.9, 0.5])), delivery: .read, isOutgoing: true),
            Message(id: "m-20", senderID: them, sentAt: at(12), kind: .text("Plus opens the 2×4 attach sheet. Poll / Event / AI are gated.", preview: nil), isOutgoing: false),
            Message(id: "m-21", senderID: them, sentAt: at(8), kind: .text("Unread separator sits on this line.", preview: nil), isOutgoing: false),
            Message(id: "m-22", senderID: me, sentAt: at(4), kind: .text("Drag the list down to dismiss the keyboard with the finger.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-23", senderID: them, sentAt: at(2), kind: .text("Ready for a drop-in.", preview: nil), reactions: [Reaction(emoji: "👍", userIDs: [me])], isOutgoing: false)
        ]
    }

    static func glyphData(title: String, color: UIColor) -> Data {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 48).fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let text = title as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
        return image.pngData() ?? Data()
    }
}
