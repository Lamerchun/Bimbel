import XCTest
@testable import Bimbel

final class InboxFilteringTests: XCTestCase {
    func testUnreadFilterIncludesCountAndMarkedUnread() {
        let items = [
            InboxItem(id: "a", title: "Ada", preview: "Hi", timestamp: Date(), unreadCount: 2),
            InboxItem(id: "b", title: "Jules", preview: "Later", timestamp: Date(), unreadCount: 0),
            InboxItem(id: "c", title: "Nico", preview: InboxAttachmentLabel.photo, timestamp: Date(), markedUnread: true)
        ]
        let visible = InboxFiltering.visible(items: items, query: "", unreadOnly: true)
        XCTAssertEqual(visible.map(\.id), ["a", "c"])
    }

    func testQueryMatchesTitleOrParticipantNotPreview() {
        let items = [
            InboxItem(
                id: "a",
                title: "Ada",
                preview: "Keyboard tracking",
                timestamp: Date(),
                participantNames: ["Ada"]
            ),
            InboxItem(
                id: "b",
                title: "Design",
                preview: "Moodboard is in the shared folder.",
                timestamp: Date(),
                isGroup: true,
                previewSenderName: "Mira",
                participantNames: ["Mira", "Ada", "Jules"]
            ),
            InboxItem(
                id: "c",
                title: "Jules",
                preview: "See you",
                timestamp: Date(),
                participantNames: ["Jules"]
            )
        ]
        XCTAssertEqual(InboxFiltering.visible(items: items, query: "ada", unreadOnly: false).map(\.id), ["a", "b"])
        XCTAssertTrue(InboxFiltering.visible(items: items, query: "keyboard", unreadOnly: false).isEmpty)
        XCTAssertEqual(InboxFiltering.visible(items: items, query: "mira", unreadOnly: false).map(\.id), ["b"])
        XCTAssertTrue(InboxFiltering.visible(items: items, query: "moodboard", unreadOnly: false).isEmpty)
    }

    func testPinnedSectionSplitsFromHostFlag() {
        let items = [
            InboxItem(id: "p", title: "Design", preview: "Hi", timestamp: Date(), isPinned: true),
            InboxItem(id: "c", title: "Ada", preview: "Hi", timestamp: Date())
        ]
        let parts = InboxFiltering.sections(items: items, query: "", unreadOnly: false)
        XCTAssertEqual(parts.pinned.map(\.id), ["p"])
        XCTAssertEqual(parts.chats.map(\.id), ["c"])
    }

    func testRelativeTimeTodayUsesClock() {
        let now = Date()
        let text = BimbelFormatters.relativeTime(now, now: now)
        XCTAssertFalse(text.isEmpty)
        XCTAssertFalse(text.localizedCaseInsensitiveContains("yesterday"))
    }
}
