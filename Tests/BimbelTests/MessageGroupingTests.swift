import XCTest
@testable import Bimbel

final class MessageGroupingTests: XCTestCase {
    private let me = "me"
    private let them = "them"
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    func testMediaStackJoinsImageLinkAndTrailingText() {
        let image = message("1", outgoing: true, kind: .image(Media(source: .data(Data()))))
        let link = message(
            "2",
            outgoing: true,
            kind: .text("check this", preview: LinkPreview(url: URL(string: "https://example.com")!))
        )
        let text = message("3", outgoing: true, kind: .text("and a caption", preview: nil))
        let rows = MessageGrouping.rows(
            from: ConversationSnapshot(conversationID: "c", messages: [image, link, text])
        )
        let decorations = rows.compactMap { row -> MessageDecoration? in
            if case .message(_, let decoration) = row { return decoration }
            return nil
        }
        XCTAssertEqual(decorations.map(\.mediaStack), [.first, .middle, .last])
    }

    func testPlainTextDoesNotFlattenLikeIMessage() {
        let a = message("1", outgoing: true, kind: .text("one", preview: nil))
        let b = message("2", outgoing: true, kind: .text("two", preview: nil))
        let rows = MessageGrouping.rows(
            from: ConversationSnapshot(conversationID: "c", messages: [a, b])
        )
        let decorations = rows.compactMap { row -> MessageDecoration? in
            if case .message(_, let decoration) = row { return decoration }
            return nil
        }
        XCTAssertEqual(decorations.map(\.mediaStack), [.none, .none])
        XCTAssertEqual(decorations.map(\.cluster), [.first, .last])
    }

    func testIncomingAvatarHiddenInOneToOne() {
        let a = message("1", outgoing: false, kind: .text("hi", preview: nil))
        let b = message("2", outgoing: false, kind: .text("there", preview: nil))
        let rows = MessageGrouping.rows(
            from: ConversationSnapshot(conversationID: "c", messages: [a, b])
        )
        let decorations = rows.compactMap { row -> MessageDecoration? in
            if case .message(_, let decoration) = row { return decoration }
            return nil
        }
        XCTAssertEqual(decorations.map(\.showsIncomingAvatar), [false, false])
    }

    func testIncomingAvatarOnlyAtGroupSequenceEnd() {
        let a = message("1", outgoing: false, kind: .text("hi", preview: nil), senderID: "ada")
        let b = message("2", outgoing: false, kind: .text("there", preview: nil), senderID: "ada")
        let c = message("3", outgoing: false, kind: .text("hey", preview: nil), senderID: "mira")
        let rows = MessageGrouping.rows(
            from: ConversationSnapshot(conversationID: "c", messages: [a, b, c])
        )
        let decorations = rows.compactMap { row -> MessageDecoration? in
            if case .message(_, let decoration) = row { return decoration }
            return nil
        }
        XCTAssertEqual(decorations.map(\.showsIncomingAvatar), [false, true, true])
    }

    func testSystemRowsAreNotClustered() {
        let sys = message("s", outgoing: false, kind: .system("encrypted"))
        let text = message("t", outgoing: false, kind: .text("hello", preview: nil))
        let rows = MessageGrouping.rows(
            from: ConversationSnapshot(conversationID: "c", messages: [sys, text])
        )
        XCTAssertEqual(rows.count, 3) // date + system + text
    }

    func testGroupingSpacingTokens() {
        XCTAssertEqual(ConversationTheme.default.layout.clusterGap, 3)
        XCTAssertEqual(ConversationTheme.default.layout.sequenceGap, 10)
    }

    func testBadgeFormatter() {
        XCTAssertNil(BimbelFormatters.badgeText(nil))
        XCTAssertNil(BimbelFormatters.badgeText(0))
        XCTAssertEqual(BimbelFormatters.badgeText(4), "4")
        XCTAssertEqual(BimbelFormatters.badgeText(100), "99+")
    }

    private func message(_ id: String, outgoing: Bool, kind: MessageKind, senderID: String? = nil) -> Message {
        Message(
            id: id,
            senderID: senderID ?? (outgoing ? me : them),
            sentAt: day,
            kind: kind,
            isOutgoing: outgoing
        )
    }
}
