import XCTest

/// Mid-swipe QA for leading inbox actions (Read + Pin).
/// Launch with `BIMBEL_SHOT=inbox`, drag Ada LTR, keep the attachment.
/// Does not call any package swipe API — XCUITest only.
final class InboxSwipeUITests: XCTestCase {
    func testLeadingMidSwipeOnAda() {
        let app = XCUIApplication()
        app.launchEnvironment["BIMBEL_SHOT"] = "inbox"
        app.launch()

        // Row accessibility is the joined label ("Ada, On my way., 4"), not a child "Ada".
        let ada = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "Ada")).firstMatch
        XCTAssertTrue(ada.waitForExistence(timeout: 5), "Ada row should be on the inbox")

        // Partial LTR drag so Read + Pin stay visible (full swipe is not the shot).
        let start = ada.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5))
        let end = ada.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        XCTAssertTrue(app.buttons["Read"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Pin"].exists)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "slice2-qa-01-inbox-swipe-leading"
        shot.lifetime = .keepAlways
        add(shot)
    }
}

/// Composer-Drag: downward pan on Plus / Camera must drive interactive dismiss.
/// Launch Ada with the software keyboard (Simulator: Connect Hardware Keyboard off).
final class ComposerDragUITests: XCTestCase {
    func testDownwardPanOnPlusDismissesKeyboard() {
        let app = XCUIApplication()
        app.launchEnvironment["BIMBEL_SHOT"] = "ada"
        app.launch()

        let keyboard = app.keyboards.element
        XCTAssertTrue(keyboard.waitForExistence(timeout: 6), "Ada should stand the software keyboard")

        let plus = app.buttons["Attach"]
        XCTAssertTrue(plus.waitForExistence(timeout: 3))
        let start = plus.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 360))
        start.press(forDuration: 0.08, thenDragTo: end)

        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: keyboard
        )
        wait(for: [gone], timeout: 3)
        XCTAssertFalse(keyboard.exists, "chrome pan on Plus must complete interactive dismiss")
    }
}
