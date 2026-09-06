import XCTest
@testable import Bimbel

final class MediaPagerTests: XCTestCase {
    func testCollectsOnlyImageAndVideoInOrder() {
        let messages = [
            Message(id: "t", senderID: "me", sentAt: Date(), kind: .text("Hi", preview: nil), isOutgoing: true),
            Message(id: "p1", senderID: "me", sentAt: Date(), kind: .image(Media(source: .data(Data()))), isOutgoing: true),
            Message(id: "v", senderID: "ada", sentAt: Date(), kind: .voice(Voice(duration: 2)), isOutgoing: false),
            Message(id: "p2", senderID: "ada", sentAt: Date(), kind: .video(Media(source: .data(Data()))), isOutgoing: false),
            Message(id: "d", senderID: "me", sentAt: Date(), kind: .document(Document(name: "a.pdf", byteCount: 12)), isOutgoing: true)
        ]
        let items = MediaPagerItems.collect(messages)
        XCTAssertEqual(items.map(\.id), ["p1", "p2"])
        XCTAssertEqual(MediaPagerItems.startIndex(in: items, id: "p2"), 1)
        XCTAssertEqual(MediaPagerItems.startIndex(in: items, id: "missing"), 0)
    }

    func testLongPressMediaIsImageOrVideo() {
        XCTAssertTrue(ConversationMessageMenu.isMedia(Message(
            id: "p",
            senderID: "me",
            sentAt: Date(),
            kind: .image(Media(source: .data(Data()))),
            isOutgoing: true
        )))
        XCTAssertFalse(ConversationMessageMenu.isMedia(Message(
            id: "t",
            senderID: "me",
            sentAt: Date(),
            kind: .text("Hi", preview: nil),
            isOutgoing: true
        )))
    }

    func testPagerChromeIconsAreUltraLightLine() {
        XCTAssertEqual(UIImage.SymbolConfiguration.bimbelComposerLineWeight, .ultraLight)
        XCTAssertEqual(ConversationTheme.default.layout.headerIcon, 22)
        XCTAssertEqual(ConversationTheme.default.layout.hitTarget, 44)
        for name in ["xmark", "square.and.arrow.down", "arrowshape.turn.up.right"] {
            XCTAssertFalse(name.contains(".fill"), "\(name) must stay a line glyph")
            XCTAssertNotNil(UIImage.bimbelComposerLine(name))
        }
    }
}
