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
        let firstUnread = conversationID == adaID ? messages.first(where: { $0.id == "m-18" })?.id : nil
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
            subtitle: String(localized: "online"),
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
                preview: "On my way.",
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
        let outgoingPhoto = ImageSource.data(photoData(title: "A", color: UIColor(red: 0.18, green: 0.72, blue: 0.47, alpha: 1)))
        let incomingPhoto = ImageSource.data(photoData(title: "A", color: UIColor(red: 0.74, green: 0.66, blue: 0.56, alpha: 1)))
        return [
            Message(id: "m-01", senderID: them, sentAt: at(28 * 60), kind: .system("Messages are end-to-end encrypted."), isOutgoing: false),
            Message(id: "m-02", senderID: them, sentAt: at(26 * 60), kind: .text("You make it home okay?", preview: nil), isOutgoing: false),
            Message(id: "m-03", senderID: me, sentAt: at(25 * 60 + 40), kind: .text("Just walked in. The rain was ridiculous.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-04", senderID: them, sentAt: at(25 * 60 + 10), kind: .text("I told you to take a cab.", preview: nil), isOutgoing: false),
            Message(id: "m-05", senderID: me, sentAt: at(90), kind: .text("Look what I found on the desk.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-06", senderID: me, sentAt: at(89), kind: .image(Media(source: outgoingPhoto, width: 800, height: 800)), delivery: .read, isOutgoing: true),
            Message(id: "m-07", senderID: them, sentAt: at(70), kind: .text("That's the print from last week?", preview: nil), isOutgoing: false),
            Message(id: "m-08", senderID: them, sentAt: at(69), kind: .text("Hold on — sending the one I meant.", preview: nil), isOutgoing: false),
            Message(
                id: "m-09",
                senderID: them,
                sentAt: at(68),
                kind: .image(Media(source: incomingPhoto, width: 640, height: 640)),
                reactions: [Reaction(emoji: "❤️", userIDs: [me])],
                isOutgoing: false
            ),
            Message(id: "m-10", senderID: me, sentAt: at(55), kind: .text("Yes. That's it.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-11", senderID: them, sentAt: at(50), kind: .voice(Voice(duration: 6, waveform: [0.2, 0.4, 0.8, 0.5, 0.9, 0.3, 0.6])), isOutgoing: false),
            Message(id: "m-12", senderID: me, sentAt: at(42), kind: .text("I'll pin it on the board when I get in.", preview: nil), delivery: .delivered, isOutgoing: true),
            Message(id: "m-13", senderID: them, sentAt: at(36), kind: .system("The message timer was updated. New messages will disappear from this chat after 7 days."), isOutgoing: false),
            Message(id: "m-14", senderID: them, sentAt: at(28), kind: .text("Lunch still on?", preview: nil), isOutgoing: false),
            Message(id: "m-15", senderID: me, sentAt: at(24), kind: .text("1:30 works. The usual place.", preview: nil), delivery: .read, isOutgoing: true),
            Message(id: "m-16", senderID: me, sentAt: at(20), kind: .voice(Voice(duration: 3, waveform: [0.3, 0.7, 0.4, 0.9, 0.5])), delivery: .read, isOutgoing: true),
            Message(id: "m-17", senderID: them, sentAt: at(14), kind: .text("I'll grab the window table.", preview: nil), isOutgoing: false),
            // Keyboard-up crop (composer + QWERTZ = bottom third): keep this tail short.
            // Lock 3 is the 👍 under incoming text, not under the photo (m-09 is off-screen here).
            Message(
                id: "m-18",
                senderID: them,
                sentAt: at(8),
                kind: .text("Don't forget the keys this time.", preview: nil),
                reactions: [Reaction(emoji: "👍", userIDs: [me])],
                isOutgoing: false
            ),
            Message(id: "m-19", senderID: me, sentAt: at(4), kind: .text("Already in my pocket.", preview: nil), delivery: .read, isOutgoing: true),
            Message(
                id: "m-20",
                senderID: them,
                sentAt: at(2),
                kind: .text("See you there.", preview: nil),
                reactions: [Reaction(emoji: "👍", userIDs: [me])],
                isOutgoing: false
            ),
            Message(id: "m-21", senderID: me, sentAt: at(1), kind: .text("On my way.", preview: nil), delivery: .read, isOutgoing: true)
        ]
    }

    /// Full-bleed bitmap for chat photos. No rounded plate in the pixels — the bubble clips.
    static func photoData(title: String, color: UIColor) -> Data {
        let size = CGSize(width: 720, height: 960)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 220, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
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
