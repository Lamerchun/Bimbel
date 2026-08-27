import XCTest
@testable import Bimbel

@MainActor
final class KeyboardInsetTests: XCTestCase {
    private let gap = ConversationTheme.Layout().listComposerGap

    func testListComposerGapIsEight() {
        XCTAssertEqual(ConversationTheme.default.layout.listComposerGap, 8)
        XCTAssertEqual(gap, 8)
    }

    func testOverlapIsComposerTopPlusGapNotKeyboardHeightPlusComposer() {
        // Composer sitting on the keys (top 442). Covering edge is that top + 8.
        // Do not add keyboard height (300) on top of the already-raised bar.
        let overlap = ComposerKeyboardTracker.overlap(
            collectionMaxY: 800,
            composerTopInCollection: 442,
            composerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 800 - 442 + gap)
        XCTAssertEqual(overlap, 366)
        XCTAssertNotEqual(
            overlap,
            (800 - 442) + 300 + gap,
            "must not add keyboard height on top of a layout-guide-pinned composer"
        )
    }

    func testDockedOverlapUsesComposerTop() {
        let overlap = ComposerKeyboardTracker.overlap(
            collectionMaxY: 800,
            composerTopInCollection: 708,
            composerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 100)
    }

    func testOverlapFallsBackToComposerPlusSafeArea() {
        let overlap = ComposerKeyboardTracker.overlap(
            collectionMaxY: 800,
            composerTopInCollection: nil,
            composerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 100)
    }

    func testLayoutBottomPaddingIsComposerPlusListGapNotTail() {
        XCTAssertEqual(
            ComposerKeyboardTracker.layoutBottomPadding(composerHeight: 58, listComposerGap: gap),
            58 + gap
        )
        XCTAssertEqual(
            ComposerKeyboardTracker.layoutBottomPadding(composerHeight: 58, listComposerGap: gap),
            66,
            "residual tail (~3) is inside the cell, not added on top of the 8"
        )
    }

    func testNearBottomUsesInsetFromBeforeKeyboardWrite() {
        XCTAssertTrue(
            ComposerKeyboardTracker.isNearBottom(
                contentHeight: 1200,
                offsetY: 500,
                boundsHeight: 800,
                adjustedBottomInset: 100
            )
        )
        XCTAssertFalse(
            ComposerKeyboardTracker.isNearBottom(
                contentHeight: 1200,
                offsetY: 500,
                boundsHeight: 800,
                adjustedBottomInset: 366
            )
        )
    }

    func testKeyboardFrameEndReadsCGRectWithoutCapturingNotification() {
        let rect = CGRect(x: 0, y: 442, width: 390, height: 358)
        let info: [AnyHashable: Any] = [UIResponder.keyboardFrameEndUserInfoKey: rect]
        XCTAssertEqual(ComposerKeyboardTracker.keyboardFrameEnd(from: info), rect)
        XCTAssertNil(ComposerKeyboardTracker.keyboardFrameEnd(from: nil))
    }

    func testComposerAttachesToKeyboardLayoutGuide() {
        XCTAssertTrue(ComposerView().shouldAttachToKeyboardLayoutGuide)
    }

    func testTextViewHasNoInputAccessoryView() {
        XCTAssertNil(ComposerTextView().inputAccessoryView)
    }
}
