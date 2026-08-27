import XCTest
@testable import Bimbel

@MainActor
final class KeyboardInsetTests: XCTestCase {
    private let gap = ConversationTheme.Layout().listComposerGap

    func testListComposerGapIsEight() {
        XCTAssertEqual(ConversationTheme.default.layout.listComposerGap, 8)
        XCTAssertEqual(gap, 8)
    }

    func testAccessoryOverlapIsComposerHeightPlusListGapNotKeyboardOnly() {
        // Keys at 500. Keyboard-only covering edge would be 800 - 500 + 8 = 308.
        // Accessory bar sits on the keys (top 442): composer 58 + listComposerGap 8.
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: true,
            keyboardTop: 500,
            collectionMaxY: 800,
            composerTopInCollection: 442,
            composerIsInAccessoryWindow: true,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 58 + gap + (800 - 500), "contentInset.bottom = composer height + 8 above the keys")
        XCTAssertEqual(overlap, 366)
        XCTAssertNotEqual(overlap, 800 - 500 + gap, "must not use the keys-only keyboard frame as the covering edge")
    }

    func testAccessoryDoesNotTreatKeysTopAsCoveringEdge() {
        // Convert reported the same Y as the keys (accessory not in the keyboard
        // window). Covering edge is still the bar on the keys, not the keys.
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: true,
            keyboardTop: 500,
            collectionMaxY: 800,
            composerTopInCollection: 500,
            composerIsInAccessoryWindow: false,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 366)
        XCTAssertEqual(
            ComposerKeyboardTracker.accessoryCoveringTop(
                keyboardTop: 500,
                composerTopInCollection: 500,
                composerIsInAccessoryWindow: false,
                composerH: 58
            ),
            442
        )
    }

    func testAccessoryKeyboardFrameThatIncludesBarDoesNotDoubleCount() {
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: true,
            keyboardTop: 442,
            collectionMaxY: 800,
            composerTopInCollection: 442,
            composerIsInAccessoryWindow: true,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 366)
    }

    func testAccessoryInsetAssumesComposerAboveKeysWhenComposerTopUnknown() {
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: true,
            keyboardTop: 500,
            collectionMaxY: 800,
            composerTopInCollection: nil,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 366)
    }

    func testDockedInsetUsesComposerHeightNotKeyboardPlusComposer() {
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: false,
            keyboardTop: 800,
            collectionMaxY: 800,
            composerTopInCollection: 708,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 100)
    }

    func testAccessoryIgnoresStaleDockedComposerTopBelowKeyboard() {
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: true,
            keyboardTop: 500,
            collectionMaxY: 800,
            composerTopInCollection: 708,
            composerIsInAccessoryWindow: false,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 366)
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

    func testDockedInsetFallsBackToComposerPlusSafeArea() {
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: false,
            keyboardTop: 800,
            collectionMaxY: 800,
            composerTopInCollection: nil,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            listComposerGap: gap
        )
        XCTAssertEqual(overlap, 100)
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
}
