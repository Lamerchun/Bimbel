import XCTest
@testable import Bimbel

@MainActor
final class InboxRowContractTests: XCTestCase {
    func testPreviewHeightStableForOneAndTwoLineText() {
        let theme = ConversationTheme.default
        let expected = InboxRowMetrics.previewHeight(theme: theme)
        XCTAssertEqual(InboxRowMetrics.previewLines, 2)

        let oneLine = InboxItem(id: "j", title: "Jules", preview: "Call me when you land.", timestamp: Date())
        let twoLine = InboxItem(
            id: "s",
            title: "Studio",
            preview: "Catching up after the show. Save me a seat near the back.",
            timestamp: Date()
        )

        let cell = InboxRowCell(style: .default, reuseIdentifier: InboxRowCell.reuseID)
        cell.bounds = CGRect(x: 0, y: 0, width: 390, height: 88)
        cell.configure(item: oneLine, theme: theme, hidesTrailingAccessories: false)
        cell.layoutIfNeeded()
        let heightOne = cell.reservedPreviewHeight

        cell.configure(item: twoLine, theme: theme, hidesTrailingAccessories: false)
        cell.layoutIfNeeded()
        let heightTwo = cell.reservedPreviewHeight

        XCTAssertEqual(heightOne, expected)
        XCTAssertEqual(heightTwo, expected)
        XCTAssertEqual(heightOne, heightTwo)
    }

    func testUnreadPillVersusEmptyDot() {
        let theme = ConversationTheme.default
        let cell = InboxRowCell(style: .default, reuseIdentifier: InboxRowCell.reuseID)
        cell.bounds = CGRect(x: 0, y: 0, width: 390, height: 88)

        let pill = InboxItem(id: "a", title: "Ada", preview: "On my way.", timestamp: Date(), unreadCount: 4)
        cell.configure(item: pill, theme: theme, hidesTrailingAccessories: false)
        XCTAssertTrue(cell.showsUnreadPill)
        XCTAssertFalse(cell.showsUnreadDot)

        let dot = InboxItem(
            id: "n",
            title: "Nico",
            preview: InboxAttachmentLabel.photo,
            timestamp: Date(),
            markedUnread: true
        )
        cell.configure(item: dot, theme: theme, hidesTrailingAccessories: false)
        XCTAssertFalse(cell.showsUnreadPill)
        XCTAssertTrue(cell.showsUnreadDot)
    }

    func testSearchOverrideHidesUnreadAndStatus() {
        let item = InboxItem(
            id: "a",
            title: "Ada",
            preview: "On my way.",
            timestamp: Date(),
            unreadCount: 4,
            isMuted: true,
            lastOutgoingDelivery: .read
        )
        let cell = InboxRowCell(style: .default, reuseIdentifier: InboxRowCell.reuseID)
        cell.configure(item: item, theme: .default, hidesTrailingAccessories: true)
        XCTAssertFalse(cell.showsUnreadPill)
        XCTAssertFalse(cell.showsUnreadDot)
        XCTAssertFalse(cell.showsOutgoingStatus)
        XCTAssertTrue(cell.showsMuteGlyph)
    }

    func testMuteAndOutgoingStatusVisibleOnHostPreview() {
        let item = InboxItem(
            id: "a",
            title: "Ada",
            preview: "On my way.",
            timestamp: Date(),
            isMuted: true,
            lastOutgoingDelivery: .read
        )
        let cell = InboxRowCell(style: .default, reuseIdentifier: InboxRowCell.reuseID)
        cell.configure(item: item, theme: .default, hidesTrailingAccessories: false)
        XCTAssertTrue(cell.showsMuteGlyph)
        XCTAssertTrue(cell.showsOutgoingStatus)
    }

    func testAvatarSizeAndSeparatorInset() {
        XCTAssertEqual(InboxRowMetrics.avatarSize, 56)
        XCTAssertEqual(InboxRowMetrics.separatorInset, 82)
    }

    func testSwipeAndMenuOrder() {
        let unread = InboxItem(id: "a", title: "Ada", preview: "Hi", timestamp: Date(), unreadCount: 4)
        XCTAssertEqual(InboxRowActionCatalog.leadingTitles(for: unread), ["Read", "Pin"])
        XCTAssertEqual(InboxRowActionCatalog.trailingTitles(for: unread), ["Mute", "Delete"])
        XCTAssertEqual(
            InboxRowActionCatalog.menuTitles(for: unread, supportsArchive: false),
            ["Read", "Pin", "Mute", "Delete"]
        )
        XCTAssertEqual(
            InboxRowActionCatalog.menuTitles(for: unread, supportsArchive: true).last,
            "Delete"
        )
        XCTAssertTrue(InboxRowActionCatalog.menuTitles(for: unread, supportsArchive: true).contains("Archive"))

        let mutedPinned = InboxItem(
            id: "j",
            title: "Jules",
            preview: "Hi",
            timestamp: Date(),
            isPinned: true,
            isMuted: true
        )
        XCTAssertEqual(InboxRowActionCatalog.leadingTitles(for: mutedPinned), ["Unread", "Unpin"])
        XCTAssertEqual(InboxRowActionCatalog.trailingTitles(for: mutedPinned), ["Unmute", "Delete"])
    }

    func testTypingUpdatesPreviewWithoutNewKind() {
        var item = InboxItem(
            id: "m",
            title: "Mira",
            preview: "On my way.",
            timestamp: Date(),
            lastOutgoingDelivery: .read
        )
        let cell = InboxRowCell(style: .default, reuseIdentifier: InboxRowCell.reuseID)
        cell.configure(item: item, theme: .default, hidesTrailingAccessories: false)
        XCTAssertEqual(cell.previewAttributedText?.string, "On my way.")
        XCTAssertTrue(cell.showsOutgoingStatus)
        cell.applyTyping(true)
        XCTAssertEqual(cell.previewAttributedText?.string, "Typing…")
        XCTAssertFalse(cell.showsOutgoingStatus)
        item.isTyping = true
        XCTAssertEqual(InboxPreviewResolver.kind(for: item), .typing)
    }
}
