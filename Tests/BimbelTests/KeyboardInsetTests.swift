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

    func testMicSendFillIsACircleNotTheButtonBackground() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 80))
        let composer = ComposerView()
        host.addSubview(composer)
        composer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            composer.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            composer.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        composer.apply(theme: .default, sendable: false, sheetPresented: false)
        host.layoutIfNeeded()

        XCTAssertEqual(composer.actionButton.backgroundColor?.cgColor.alpha ?? 0, 0, accuracy: 0.01)
        XCTAssertEqual(composer.plusButton.backgroundColor?.cgColor.alpha ?? 0, 0, accuracy: 0.01)
        XCTAssertEqual(composer.cameraButton.backgroundColor?.cgColor.alpha ?? 0, 0, accuracy: 0.01)
        XCTAssertEqual(composer.actionFill.bounds.width, 40, accuracy: 0.5)
        XCTAssertEqual(composer.actionFill.bounds.height, 40, accuracy: 0.5)
        XCTAssertEqual(composer.actionFill.layer.cornerRadius, 20, accuracy: 0.5)
        XCTAssertTrue(composer.actionFill.layer.masksToBounds)
        XCTAssertEqual(composer.actionFill.backgroundColor, ConversationTheme.default.colors.sendFill)

        composer.apply(theme: .default, sendable: true, sheetPresented: false)
        host.layoutIfNeeded()
        XCTAssertEqual(composer.actionButton.backgroundColor?.cgColor.alpha ?? 0, 0, accuracy: 0.01)
        XCTAssertEqual(composer.actionFill.backgroundColor, ConversationTheme.default.colors.sendFill)
    }

    func testMessagePillIsACapsuleNotTheViewBackground() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 80))
        let composer = ComposerView()
        host.addSubview(composer)
        composer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            composer.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            composer.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        composer.apply(theme: .default, sendable: false, sheetPresented: false)
        host.layoutIfNeeded()

        XCTAssertEqual(composer.pill.backgroundColor?.cgColor.alpha ?? 0, 0, accuracy: 0.01)
        XCTAssertGreaterThan(composer.pillFill.bounds.height, 1)
        XCTAssertEqual(
            composer.pillFill.layer.cornerRadius,
            composer.pillFill.bounds.height / 2,
            accuracy: 0.5
        )
        XCTAssertGreaterThan(composer.pillFill.layer.cornerRadius, 1)
        XCTAssertTrue(composer.pillFill.layer.masksToBounds)
        XCTAssertEqual(composer.pillFill.layer.cornerCurve, .continuous)
        XCTAssertEqual(composer.pillFill.backgroundColor, ConversationTheme.default.colors.composerFill)
        XCTAssertEqual(composer.pill.layer.borderWidth, 0)
    }

    func testCapsuleRadiusIsNeverZeroWhenHeightIsZero() {
        let fill = ComposerCapsuleFill(frame: .zero)
        fill.applyCapsule()
        XCTAssertEqual(fill.layer.cornerRadius, 20)
        fill.bounds = CGRect(x: 0, y: 0, width: 200, height: 40)
        fill.applyCapsule()
        XCTAssertEqual(fill.layer.cornerRadius, 20)
        fill.bounds = CGRect(x: 0, y: 0, width: 200, height: 80)
        fill.applyCapsule()
        XCTAssertEqual(fill.layer.cornerRadius, 40)
    }
}
