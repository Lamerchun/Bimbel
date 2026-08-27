import XCTest
@testable import Bimbel

@MainActor
final class KeyboardInsetTests: XCTestCase {
    func testAccessoryInsetIncludesComposerWhenKeyboardFrameIsKeysOnly() {
        // Keyboard top is the keys; self-sizing accessory sits 58pt above.
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: true,
            keyboardTop: 500,
            collectionMaxY: 800,
            composerTopInCollection: 442,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            breathing: 8
        )
        XCTAssertEqual(overlap, 366)
    }

    func testAccessoryInsetDoesNotDoubleCountWhenKeyboardIncludesComposer() {
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: true,
            keyboardTop: 442,
            collectionMaxY: 800,
            composerTopInCollection: 442,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            breathing: 8
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
            breathing: 8
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
            breathing: 8
        )
        XCTAssertEqual(overlap, 100)
    }

    func testAccessoryIgnoresStaleDockedComposerTopBelowKeyboard() {
        // Cross-window convert returned the docked Y (708) while keys sit at 500.
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: true,
            keyboardTop: 500,
            collectionMaxY: 800,
            composerTopInCollection: 708,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            breathing: 8
        )
        XCTAssertEqual(overlap, 366)
    }

    func testLayoutBottomPaddingIsComposerPlusGap() {
        XCTAssertEqual(ComposerKeyboardTracker.layoutBottomPadding(composerHeight: 58, breathing: 8), 66)
    }

    func testDockedInsetFallsBackToComposerPlusSafeArea() {
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: false,
            keyboardTop: 800,
            collectionMaxY: 800,
            composerTopInCollection: nil,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            breathing: 8
        )
        XCTAssertEqual(overlap, 100)
    }

    func testNearBottomUsesInsetFromBeforeKeyboardWrite() {
        // Pinned to bottom while docked (inset 100).
        XCTAssertTrue(
            ComposerKeyboardTracker.isNearBottom(
                contentHeight: 1200,
                offsetY: 500,
                boundsHeight: 800,
                adjustedBottomInset: 100
            )
        )
        // Same offset after contentInset.bottom grows for the accessory+keys.
        // Must not treat this as a user scroll-away or the keyboard-up pin is skipped.
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
