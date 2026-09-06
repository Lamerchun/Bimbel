import XCTest
@testable import Bimbel

final class ConversationMessageMenuTests: XCTestCase {
    func testTextMenuOrderAndEditGate() {
        let text = Message(
            id: "t",
            senderID: "me",
            sentAt: Date(),
            kind: .text("On my way.", preview: nil),
            isOutgoing: true
        )
        XCTAssertEqual(
            ConversationMessageMenu.items(for: text, allowsEdit: false).map(\.title),
            ["Reply", "Copy", "Forward", "Delete", "Select"]
        )
        XCTAssertEqual(
            ConversationMessageMenu.items(for: text, allowsEdit: true).map(\.title),
            ["Reply", "Copy", "Forward", "Delete", "Select", "Edit"]
        )
    }

    func testMediaMenuHasSaveNotCopy() {
        let photo = Message(
            id: "p",
            senderID: "ada",
            sentAt: Date(),
            kind: .image(Media(source: .data(Data()))),
            isOutgoing: false
        )
        XCTAssertEqual(
            ConversationMessageMenu.items(for: photo, allowsEdit: false).map(\.title),
            ["Reply", "Save", "Forward", "Delete", "Select"]
        )
        XCTAssertEqual(
            ConversationMessageMenu.items(for: photo, allowsEdit: true).map(\.title),
            ["Reply", "Save", "Forward", "Delete", "Select", "Edit"]
        )
        XCTAssertFalse(ConversationMessageMenu.items(for: photo, allowsEdit: true).contains(.copy))
    }

    func testEditGateDefaultsClosed() {
        let actions = ConversationActions()
        let outgoing = Message(
            id: "t",
            senderID: "me",
            sentAt: Date(),
            kind: .text("Hi", preview: nil),
            isOutgoing: true
        )
        XCTAssertFalse(actions.allowsEdit(outgoing))
        let open = ConversationActions(canEdit: { $0.isOutgoing })
        XCTAssertTrue(open.allowsEdit(outgoing))
        XCTAssertFalse(open.allowsEdit(Message(
            id: "i",
            senderID: "ada",
            sentAt: Date(),
            kind: .text("Hi", preview: nil),
            isOutgoing: false
        )))
    }

    func testDeleteIsDestructiveLastBeforeOptionalEdit() {
        let items = ConversationMessageMenu.items(
            for: Message(
                id: "t",
                senderID: "me",
                sentAt: Date(),
                kind: .text("Hi", preview: nil),
                isOutgoing: true
            ),
            allowsEdit: true
        )
        XCTAssertTrue(items.contains(.delete))
        XCTAssertTrue(ConversationMessageMenuItem.delete.isDestructive)
    }
}
