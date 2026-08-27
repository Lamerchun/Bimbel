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
}
