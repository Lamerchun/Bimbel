import XCTest
@testable import Bimbel

@MainActor
final class VoiceRecordingTests: XCTestCase {
    func testHoldGestureLockIsUpAndCancelIsLeft() {
        let cancelAt = ConversationTheme.default.layout.voiceCancelTranslation
        let lockAt = ConversationTheme.default.layout.voiceLockTranslation
        XCTAssertEqual(cancelAt, 80)
        XCTAssertEqual(lockAt, 80)

        XCTAssertEqual(
            VoiceGesture.outcome(translation: CGPoint(x: -80, y: 0), cancelAt: cancelAt, lockAt: lockAt),
            .cancel
        )
        XCTAssertEqual(
            VoiceGesture.outcome(translation: CGPoint(x: 0, y: -80), cancelAt: cancelAt, lockAt: lockAt),
            .lock
        )
        XCTAssertEqual(
            VoiceGesture.outcome(translation: CGPoint(x: -90, y: -40), cancelAt: cancelAt, lockAt: lockAt),
            .cancel
        )
        XCTAssertEqual(
            VoiceGesture.outcome(translation: CGPoint(x: -40, y: -90), cancelAt: cancelAt, lockAt: lockAt),
            .lock
        )
        XCTAssertNil(VoiceGesture.outcome(translation: CGPoint(x: -20, y: -20), cancelAt: cancelAt, lockAt: lockAt))
        XCTAssertNil(VoiceGesture.outcome(translation: CGPoint(x: 40, y: 10), cancelAt: cancelAt, lockAt: lockAt))
    }

    func testHoldCopyHasNoBrandNames() {
        let overlay = VoiceLockOverlay()
        overlay.showRecording()
        XCTAssertFalse(overlay.isHidden)
        let joined = overlay.accessibilityElementsFlattened
        XCTAssertFalse(joined.contains("WhatsApp"))
        XCTAssertFalse(joined.contains("Signal"))
        XCTAssertFalse(joined.contains("Telegram"))
        XCTAssertFalse(joined.contains("iMessage"))
        overlay.showLocked()
        overlay.hide()
        XCTAssertTrue(overlay.isHidden)
    }
}

private extension UIView {
    var accessibilityElementsFlattened: String {
        var parts: [String] = []
        if let label = accessibilityLabel { parts.append(label) }
        for child in subviews {
            parts.append(child.accessibilityElementsFlattened)
            if let label = (child as? UILabel)?.text { parts.append(label) }
            if let button = child as? UIButton, let title = button.currentTitle { parts.append(title) }
        }
        return parts.joined(separator: " ")
    }
}
