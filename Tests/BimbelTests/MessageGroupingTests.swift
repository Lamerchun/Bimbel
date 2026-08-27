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

    func testIncomingAvatarAtGroupClusterStart() {
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
        XCTAssertEqual(decorations.map(\.showsIncomingAvatar), [true, false, true])
        XCTAssertEqual(decorations.map(\.reservesIncomingAvatarGutter), [true, true, true])
    }

    func testOneToOneDoesNotReserveAvatarGutter() {
        let a = message("1", outgoing: false, kind: .text("hi", preview: nil))
        let rows = MessageGrouping.rows(
            from: ConversationSnapshot(conversationID: "c", messages: [a])
        )
        let decorations = rows.compactMap { row -> MessageDecoration? in
            if case .message(_, let decoration) = row { return decoration }
            return nil
        }
        XCTAssertEqual(decorations.map(\.reservesIncomingAvatarGutter), [false])
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
        XCTAssertEqual(ConversationTheme.default.radii.residualTail, 3)
        XCTAssertEqual(ConversationTheme.default.radii.bubble, 22)
        XCTAssertEqual(ConversationTheme.default.materials.headerBlurStyle, .systemChromeMaterial)
    }

    func testImageCaptionBecomesFollowingTextInMediaStack() {
        let photo = message(
            "1",
            outgoing: false,
            kind: .image(Media(source: .data(Data()), caption: "Logo"))
        )
        let rows = MessageGrouping.rows(
            from: ConversationSnapshot(conversationID: "c", messages: [photo])
        )
        let kinds = rows.compactMap { row -> String? in
            guard case .message(let message, _) = row else { return nil }
            switch message.kind {
            case .image: return "image"
            case .text(let body, _): return body
            default: return nil
            }
        }
        XCTAssertEqual(kinds, ["image", "Logo"])
        let decorations = rows.compactMap { row -> MessageDecoration? in
            if case .message(_, let decoration) = row { return decoration }
            return nil
        }
        XCTAssertEqual(decorations.map(\.mediaStack), [.first, .last])
    }

    func testUnreadSeparatorIsCenteredChipNotHairline() {
        let cell = UnreadSeparatorCell(frame: CGRect(x: 0, y: 0, width: 390, height: 36))
        cell.configure(theme: .default)
        XCTAssertEqual(cell.contentView.subviews.count, 1, "unread must be a single chip, no hairline view")
        let chip = try XCTUnwrap(cell.contentView.subviews.first)
        XCTAssertGreaterThan(chip.layer.cornerRadius, 8)
        XCTAssertFalse(cell.contentView.subviews.contains { abs($0.frame.height - 1) < 0.5 })
    }

    func testReactionStaysOnIncomingTextNotMovedToCaptionRow() {
        let text = message(
            "keys",
            outgoing: false,
            kind: .text("Don't forget the keys this time.", preview: nil)
        )
        var withReaction = text
        withReaction.reactions = [Reaction(emoji: "👍", userIDs: [me])]
        let rows = MessageGrouping.rows(
            from: ConversationSnapshot(conversationID: "c", messages: [withReaction])
        )
        let reacted = rows.compactMap { row -> Message? in
            guard case .message(let message, _) = row else { return nil }
            return message.reactions.isEmpty ? nil : message
        }
        XCTAssertEqual(reacted.count, 1)
        if case .text(let body, _) = reacted[0].kind {
            XCTAssertEqual(body, "Don't forget the keys this time.")
        } else {
            XCTFail("Lock 3 reaction must sit on incoming text, not media")
        }
    }

    func testDeliveryTicksAreOverlappingTemplateGlyphNotSFCheckmark() {
        let sent = try XCTUnwrap(DeliveryTicks.image(for: .sent))
        let delivered = try XCTUnwrap(DeliveryTicks.image(for: .delivered))
        let read = try XCTUnwrap(DeliveryTicks.image(for: .read))
        XCTAssertEqual(sent.size, CGSize(width: 12, height: 12))
        XCTAssertEqual(delivered.size, CGSize(width: 20, height: 12))
        XCTAssertEqual(read.size, CGSize(width: 20, height: 12))
        XCTAssertEqual(sent.renderingMode, .alwaysTemplate)
        XCTAssertEqual(delivered.renderingMode, .alwaysTemplate)
        XCTAssertEqual(read.renderingMode, .alwaysTemplate)
        XCTAssertGreaterThan(delivered.size.width, sent.size.width)
    }

    func testDateChipSaysToday() {
        XCTAssertEqual(BimbelFormatters.dateChipText(Date()), "Today")
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
