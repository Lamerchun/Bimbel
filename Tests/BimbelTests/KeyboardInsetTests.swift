import XCTest
@testable import Bimbel

@MainActor
final class KeyboardInsetTests: XCTestCase {
    func testAccessoryInsetDoesNotAddComposerOnTopOfKeyboard() {
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: true,
            keyboardTop: 500,
            collectionMaxY: 800,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            breathing: 8
        )
        XCTAssertEqual(overlap, 308)
    }

    func testDockedInsetUsesComposerHeightNotKeyboardPlusComposer() {
        let overlap = ComposerKeyboardTracker.overlap(
            isComposerInAccessory: false,
            keyboardTop: 800,
            collectionMaxY: 800,
            dockedComposerHeight: 58,
            safeAreaBottom: 34,
            breathing: 8
        )
        XCTAssertEqual(overlap, 100)
    }
}
