import XCTest
@testable import Bimbel

final class InboxFilteringTests: XCTestCase {
    func testUnreadFilterHidesReadRows() {
        let items = [
            InboxItem(id: "a", title: "Ada", preview: "Hi", timestamp: Date(), unreadCount: 2),
            InboxItem(id: "b", title: "Jules", preview: "Later", timestamp: Date(), unreadCount: 0)
        ]
        let visible = InboxFiltering.visible(items: items, query: "", unreadOnly: true)
        XCTAssertEqual(visible.map(\.id), ["a"])
    }

    func testQueryMatchesTitleOrPreview() {
        let items = [
            InboxItem(id: "a", title: "Ada", preview: "Keyboard tracking", timestamp: Date()),
            InboxItem(id: "b", title: "Jules", preview: "See you", timestamp: Date())
        ]
        XCTAssertEqual(InboxFiltering.visible(items: items, query: "ada", unreadOnly: false).map(\.id), ["a"])
        XCTAssertEqual(InboxFiltering.visible(items: items, query: "keyboard", unreadOnly: false).map(\.id), ["a"])
        XCTAssertTrue(InboxFiltering.visible(items: items, query: "nope", unreadOnly: false).isEmpty)
    }

    func testRelativeTimeTodayUsesClock() {
        let now = Date()
        let text = BimbelFormatters.relativeTime(now, now: now)
        XCTAssertFalse(text.isEmpty)
        XCTAssertFalse(text.localizedCaseInsensitiveContains("yesterday"))
    }
}
