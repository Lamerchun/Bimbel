import Bimbel
import UIKit

/// In-memory host store for inbox + threads. No network. The package never mints IDs.
@MainActor
final class FakeConversationDataSource: ConversationDataSource, InboxDataSource {
    let adaID: ConversationID = "sample-thread"
    var conversationID: ConversationID { adaID }
    let me: UserID = "me"
    private(set) var isTyping = false
    private var items: [InboxItem] = []
    private var threads: [ConversationID: [Message]] = [:]
    private var olderExhausted: Set<ConversationID> = []

    init() {
        let now = Date()
        items = Self.seedItems(now: now)
        threads[adaID] = Self.seedAda(me: me, them: "ada")
        threads["jules"] = Self.shortThread(idPrefix: "j", peer: "jules", me: me, line: "Call me when you land.", minutesAgo: 80)
        threads["design"] = Self.shortThread(idPrefix: "d", peer: "design", me: me, line: "Ship the inbox surface today.", minutesAgo: 180, outgoingLast: false)
        threads["mira"] = Self.shortThread(idPrefix: "mi", peer: "mira", me: me, line: "Can you look at the header glass?", minutesAgo: 12)
        threads["nico"] = Self.shortThread(idPrefix: "n", peer: "nico", me: me, line: "Voice lock feels right.", minutesAgo: 3 * 1_440)
        threads["studio"] = Self.shortThread(idPrefix: "s", peer: "studio", me: me, line: "Muted this one on purpose.", minutesAgo: 2 * 1_440)
    }

    func snapshot() -> InboxSnapshot {
        InboxSnapshot(items: items)
    }

    func snapshot(in conversationID: ConversationID) -> ConversationSnapshot {
        let messages = threads[conversationID] ?? []
        let firstUnread = conversationID == adaID ? messages.first(where: { $0.id == "m-21" })?.id : nil
        return ConversationSnapshot(
            conversationID: conversationID,
            messages: messages,
            firstUnreadID: firstUnread
        )
    }

    func loadOlder(in conversationID: ConversationID) async throws -> ConversationSnapshot {
        try await Task.sleep(nanoseconds: 250_000_000)
        if !olderExhausted.contains(conversationID) {
            olderExhausted.insert(conversationID)
            let peer = peerID(for: conversationID)
            let older = (0..<8).map { index in
                Message(
                    id: "\(conversationID)-old-\(index)",
                    senderID: index.isMultiple(of: 2) ? peer : me,
                    sentAt: Date().addingTimeInterval(-86_400 * 3 - Double(8 - index) * 90),
                    kind: .text("Older line \(index + 1)", preview: nil),
                    isOutgoing: !index.isMultiple(of: 2)
                )
            }
            threads[conversationID, default: []].insert(contentsOf: older, at: 0)
        }
        return snapshot(in: conversationID)
    }

    func participant(id: UserID) -> Participant? {
        switch id {
        case me:
            return Participant(id: me, displayName: "You", nameColorToken: "self")
        case "ada":
            return Participant(id: "ada", displayName: "Ada", avatar: .data(Self.glyphData(title: "A", color: .systemGreen)))
        case "jules":
            return Participant(id: "jules", displayName: "Jules", avatar: .data(Self.glyphData(title: "J", color: .systemOrange)))
        case "mira":
            return Participant(id: "mira", displayName: "Mira", avatar: .data(Self.glyphData(title: "M", color: .systemPurple)))
        case "nico":
            return Participant(id: "nico", displayName: "Nico", avatar: .data(Self.glyphData(title: "N", color: .systemBlue)))
        case "studio":
            return Participant(id: "studio", displayName: "Studio", avatar: .data(Self.glyphData(title: "S", color: .systemGray)))
        case "design":
            return Participant(id: "design", displayName: "Design", avatar: .data(Self.glyphData(title: "D", color: .systemTeal)))
        default:
            return nil
        }
    }

    func header(for conversationID: ConversationID) -> HeaderContent {
        let item = items.first(where: { $0.id == conversationID })
        let typing = conversationID == adaID ? isTyping : (item?.isTyping ?? false)
        return HeaderContent(
            title: item?.title ?? "Chat",
            subtitle: "tap name to switch theme",
            avatar: item?.avatar,
            unreadBadge: item?.unreadCount,
            showsVideo: true,
            showsCall: true,
            showsUnifiedCall: false,
            isTyping: typing
        )
    }

    func toggleTyping() {
        isTyping.toggle()
        updateItem(adaID) { $0.isTyping = isTyping }
    }

    func sendText(_ text: String, in conversationID: ConversationID) -> Message {
        let message = Message(
            id: UUID().uuidString,
            senderID: me,
            sentAt: Date(),
            kind: .text(text, preview: nil),
            delivery: .sent,
            isOutgoing: true
        )
        threads[conversationID, default: []].append(message)
        updateItem(conversationID) { item in
            item.preview = text
            item.timestamp = message.sentAt
            item.unreadCount = 0
            item.isTyping = false
        }
        return message
    }

    func sendAttachments(_ attachments: [StagedAttachment], in conversationID: ConversationID) -> Message {
        let kind: MessageKind
        let preview: String
        if let first = attachments.first {
            switch first.kind {
            case .image(let source):
                kind = .image(Media(source: source, width: 800, height: 800))
                preview = "Photo"
            case .video(let source):
                kind = .video(Media(source: source, width: 800, height: 800, duration: 12))
                preview = "Video"
            case .document(let document):
                kind = .document(document)
                preview = document.name
            case .location(_, _, let label):
                preview = label ?? "Dropped pin"
                kind = .text(preview, preview: nil)
            case .contact(let name):
                preview = name
                kind = .text(name, preview: nil)
            }
        } else {
            preview = "Attachment"
            kind = .text(preview, preview: nil)
        }
        let message = Message(
            id: UUID().uuidString,
            senderID: me,
            sentAt: Date(),
            kind: kind,
            delivery: .sent,
            isOutgoing: true
        )
        threads[conversationID, default: []].append(message)
        updateItem(conversationID) { item in
            item.preview = preview
            item.timestamp = message.sentAt
            item.unreadCount = 0
        }
        return message
    }

    func sendVoice(_ url: URL, in conversationID: ConversationID) -> Message {
        let message = Message(
            id: UUID().uuidString,
            senderID: me,
            sentAt: Date(),
            kind: .voice(Voice(duration: 4, waveform: [0.2, 0.6, 0.4, 0.9, 0.3, 0.7], fileURL: url)),
            delivery: .sent,
            isOutgoing: true
        )
        threads[conversationID, default: []].append(message)
        updateItem(conversationID) { item in
            item.preview = "Voice message"
            item.timestamp = message.sentAt
            item.unreadCount = 0
        }
        return message
    }

    func addReaction(to id: MessageID, in conversationID: ConversationID, emoji: String) {
        guard var messages = threads[conversationID],
              let index = messages.firstIndex(where: { $0.id == id }) else { return }
        var reactions = messages[index].reactions
        if let existing = reactions.firstIndex(where: { $0.emoji == emoji }) {
            if !reactions[existing].userIDs.contains(me) {
                reactions[existing].userIDs.append(me)
            }
        } else {
            reactions.append(Reaction(emoji: emoji, userIDs: [me]))
        }
        messages[index].reactions = reactions
        threads[conversationID] = messages
    }

    func markRead(_ id: ConversationID) {
        updateItem(id) { $0.unreadCount = 0 }
    }

    func togglePin(_ id: ConversationID) {
        updateItem(id) { $0.isPinned.toggle() }
        items.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.timestamp > $1.timestamp
        }
    }

    func toggleMute(_ id: ConversationID) {
        updateItem(id) { $0.isMuted.toggle() }
    }

    func delete(_ id: ConversationID) {
        items.removeAll { $0.id == id }
        threads[id] = nil
    }

    private func updateItem(_ id: ConversationID, mutate: (inout InboxItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
    }

    private func peerID(for conversationID: ConversationID) -> UserID {
        conversationID == adaID ? "ada" : conversationID
    }

    private static func seedItems(now: Date) -> [InboxItem] {
        let adaAvatar = ImageSource.data(glyphData(title: "A", color: .systemGreen))
        return [
            InboxItem(
                id: "design",
                title: "Design",
                preview: "Ship the inbox surface today.",
                timestamp: now.addingTimeInterval(-180 * 60),
                avatar: .data(glyphData(title: "D", color: .systemTeal)),
                unreadCount: 0,
                isPinned: true,
                isGroup: true
            ),
            InboxItem(
                id: "sample-thread",
                title: "Ada",
                preview: "Ready for a drop-in.",
                timestamp: now.addingTimeInterval(-2 * 60),
                avatar: adaAvatar,
                unreadCount: 4
            ),
            InboxItem(
                id: "mira",
                title: "Mira",
                preview: "Can you look at the header glass?",
                timestamp: now.addingTimeInterval(-12 * 60),
                avatar: .data(glyphData(title: "M", color: .systemPurple)),
                unreadCount: 1,
                isTyping: true
            ),
            InboxItem(
                id: "jules",
                title: "Jules",
                preview: "Call me when you land.",
                timestamp: now.addingTimeInterval(-80 * 60),
                avatar: .data(glyphData(title: "J", color: .systemOrange)),
                isMuted: true
            ),
            InboxItem(
                id: "nico",
                title: "Nico",
                preview: "Voice lock feels right.",
                timestamp: now.addingTimeInterval(-3 * 86_400),
                avatar: .data(glyphData(title: "N", color: .systemBlue)),
                unreadCount: 2
            ),
            InboxItem(
                id: "studio",
                title: "Studio",
                preview: "Muted this one on purpose.",
                timestamp: now.addingTimeInterval(-2 * 86_400),
                avatar: .data(glyphData(title: "S", color: .systemGray)),
                isMuted: true
            )
        ]
    }

    private static func shortThread(
        idPrefix: String,
        peer: UserID,
        me: UserID,
        line: String,
        minutesAgo: TimeInterval,
        outgoingLast: Bool = false
    ) -> [Message] {
        let sent = Date().addingTimeInterval(-minutesAgo * 60)
        return [
            Message(
                id: "\(idPrefix)-1",
                senderID: outgoingLast ? me : peer,
                sentAt: sent.addingTimeInterval(-120),
                kind: .text("Hey", preview: nil),
                isOutgoing: outgoingLast
            ),
            Message(
                id: "\(idPrefix)-2",
                senderID: outgoingLast ? peer : me,
                sentAt: sent.addingTimeInterval(-60),
                kind: .text(outgoingLast ? "On it." : "Sounds good.", preview: nil),
                delivery: .read,
                isOutgoing: !outgoingLast
            ),
            Message(
                id: "\(idPrefix)-3",
                senderID: outgoingLast ? me : peer,
                sentAt: sent,
                kind: .text(line, preview: nil),
                delivery: .sent,
                isOutgoing: outgoingLast
            )
        ]
    }

    private static func seedAda(me: UserID, them: UserID) -> [Message] {
        let now = Date()
        func at(_ minutes: TimeInterval) -> Date { now.addingTimeInterval(-minutes * 60) }
        let logo = ImageSource.data(glyphData(title: "A", color: UIColor(red: 0.18, green: 0.72, blue: 0.47, alpha: 1)))
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
            Message(id: "m-16", senderID: me, sentAt: at(60), kind: .text("Back returns to the inbox. Tap a title to switch theme.", preview: nil), delivery: .read, isOutgoing: true),
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
