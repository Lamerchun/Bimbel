import XCTest
@testable import Bimbel

@MainActor
final class VoiceRecordingTests: XCTestCase {
    func testHoldGestureLockIsUpAndCancelIsLeft() {
        let cancelAt = ConversationTheme.default.layout.voiceCancelTranslation
        let lockAt = ConversationTheme.default.layout.voiceLockTranslation
        XCTAssertEqual(cancelAt, 72)
        XCTAssertEqual(lockAt, 56)

        XCTAssertEqual(
            VoiceGesture.outcome(translation: CGPoint(x: -72, y: 0), cancelAt: cancelAt, lockAt: lockAt),
            .cancel
        )
        XCTAssertEqual(
            VoiceGesture.outcome(translation: CGPoint(x: 0, y: -56), cancelAt: cancelAt, lockAt: lockAt),
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

    func testFinishAfterBeginReturnsATakeWithoutCrashing() {
        let voice = VoiceRecordingController()
        voice.begin()
        XCTAssertEqual(voice.state, .recording)
        let take = voice.finish()
        XCTAssertNotNil(take)
        XCTAssertEqual(voice.state, .idle)
        XCTAssertGreaterThanOrEqual(take?.duration ?? 0, 0.2)
        XCTAssertEqual(take?.url.pathExtension, "m4a")
    }

    func testCancelAndFinishParkWriterWithoutStop() {
        let parked = VoiceRecorderPark.recorders.count
        let voice = VoiceRecordingController()
        voice.begin()
        voice.cancel()
        XCTAssertEqual(voice.state, .idle)
        XCTAssertGreaterThanOrEqual(VoiceRecorderPark.recorders.count, parked)
        voice.begin()
        XCTAssertNotNil(voice.finish())
        XCTAssertEqual(voice.state, .idle)
        XCTAssertGreaterThan(VoiceRecorderPark.recorders.count, parked)
    }

    func testCancelHintTurnsSystemRedPastSeventyTwoPoints() {
        let overlay = VoiceLockOverlay()
        overlay.apply(theme: .default)
        overlay.showRecording()
        overlay.applyHoldProgress(CGPoint(x: -71, y: 0), cancelAt: 72, lockAt: 56)
        XCTAssertEqual(overlay.cancelHintTextColor, ConversationTheme.default.colors.headerSubtitle)
        overlay.applyHoldProgress(CGPoint(x: -72, y: 0), cancelAt: 72, lockAt: 56)
        XCTAssertEqual(overlay.cancelHintTextColor, .systemRed)
        overlay.apply(theme: .default)
        XCTAssertEqual(overlay.cancelHintTextColor, .systemRed)
    }

    func testReleaseUnderThresholdSendsAndPastThresholdCancels() {
        let cancelAt = ConversationTheme.default.layout.voiceCancelTranslation
        let lockAt = ConversationTheme.default.layout.voiceLockTranslation
        XCTAssertNil(VoiceGesture.outcome(translation: CGPoint(x: -40, y: 0), cancelAt: cancelAt, lockAt: lockAt))
        XCTAssertNil(VoiceGesture.outcome(translation: CGPoint(x: -71, y: 0), cancelAt: cancelAt, lockAt: lockAt))
        XCTAssertEqual(
            VoiceGesture.outcome(translation: CGPoint(x: -72, y: 0), cancelAt: cancelAt, lockAt: lockAt),
            .cancel
        )
    }

    func testCancelPastSeventyTwoPointsHidesOverlayAndReturnsIdle() {
        let voice = VoiceRecordingController()
        let overlay = VoiceLockOverlay()
        overlay.apply(theme: .default)
        voice.onStateChange = { state in
            switch state {
            case .idle: overlay.hide()
            case .recording: overlay.showRecording()
            case .locked, .paused: overlay.showLocked()
            }
        }
        voice.begin()
        XCTAssertEqual(voice.state, .recording)
        XCTAssertFalse(overlay.isHidden)
        overlay.applyHoldProgress(CGPoint(x: -80, y: 0), cancelAt: 72, lockAt: 56)
        XCTAssertEqual(overlay.cancelHintTextColor, .systemRed)
        XCTAssertEqual(
            VoiceGesture.outcome(translation: CGPoint(x: -80, y: 0), cancelAt: 72, lockAt: 56),
            .cancel
        )
        voice.cancel()
        overlay.hide()
        XCTAssertEqual(voice.state, .idle)
        XCTAssertTrue(overlay.isHidden)
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

    func testLockUIIsPausePreviewSendDiscard() {
        let overlay = VoiceLockOverlay()
        overlay.showLocked()
        XCTAssertEqual(overlay.pauseButton.accessibilityLabel, "Pause recording")
        XCTAssertEqual(overlay.previewButton.accessibilityLabel, "Preview recording")
        XCTAssertEqual(overlay.sendButton.accessibilityLabel, "Send voice message")
        XCTAssertEqual(overlay.discardButton.accessibilityLabel, "Discard recording")
        let actions = overlay.subviews.compactMap(\.accessibilityCustomActions).flatMap { $0 }
        let names = actions.map(\.name)
        XCTAssertTrue(names.contains("Pause recording"))
        XCTAssertTrue(names.contains("Preview recording"))
        XCTAssertTrue(names.contains("Send voice message"))
        XCTAssertTrue(names.contains("Discard recording"))
    }

    func testSlice3Tokens() {
        let theme = ConversationTheme.default
        XCTAssertEqual(theme.colors.waveform.cgColor.alpha, 0.6, accuracy: 0.01)
        XCTAssertEqual(theme.colors.waveformPlayed.cgColor.alpha, 1.0, accuracy: 0.01)
        XCTAssertEqual(theme.colors.waveformAccent.cgColor.alpha, 0.6, accuracy: 0.01)
        XCTAssertEqual(theme.colors.waveformPlayedAccent.cgColor.alpha, 1.0, accuracy: 0.01)
        XCTAssertEqual(theme.layout.recordingBarHeight, 40)
        XCTAssertEqual(theme.layout.voiceCancelTranslation, 72)
        XCTAssertEqual(theme.layout.voiceLockZone, 56)
        XCTAssertEqual(theme.layout.voiceLockTranslation, 56)
        XCTAssertEqual(theme.layout.voicePlaySize, 32)
        XCTAssertEqual(theme.layout.voiceWaveformHeight, 24)
        XCTAssertEqual(theme.layout.voiceChromeDim, 0.35, accuracy: 0.001)
        XCTAssertEqual(theme.radii.lockCapsule, 22)
        XCTAssertEqual(theme.materials.composer, .systemChromeMaterial)
        XCTAssertEqual(UIImage.SymbolConfiguration.bimbelComposerLinePointSize, 22)
        XCTAssertEqual(UIImage.SymbolConfiguration.bimbelComposerLineWeight, .ultraLight)
    }

    func testRecordingBarMatchesComposerPill() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 240))
        let overlay = VoiceLockOverlay()
        host.addSubview(overlay)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: host.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        overlay.apply(theme: .default)
        overlay.showRecording()
        host.layoutIfNeeded()
        let bar = overlay.subviews.first { $0.accessibilityIdentifier == "voice.recording.bar" }
        XCTAssertEqual(bar?.bounds.height, ConversationTheme.default.layout.recordingBarHeight, accuracy: 0.5)
        let fill = bar?.subviews.first(where: { $0 is ComposerCapsuleFill })
        XCTAssertNotNil(fill)
        XCTAssertEqual(fill?.layer.borderWidth, 0)
        XCTAssertEqual(fill?.backgroundColor, ConversationTheme.default.colors.composerFill)
    }

    func testPlaybackRateCyclesOneOneAndHalfTwo() {
        XCTAssertEqual(VoicePlaybackRate.one.label, "1×")
        XCTAssertEqual(VoicePlaybackRate.oneAndHalf.label, "1.5×")
        XCTAssertEqual(VoicePlaybackRate.two.label, "2×")
        XCTAssertEqual(VoicePlaybackRate.one.next(), .oneAndHalf)
        XCTAssertEqual(VoicePlaybackRate.oneAndHalf.next(), .two)
        XCTAssertEqual(VoicePlaybackRate.two.next(), .one)
        XCTAssertEqual(VoicePlaybackRate.one.value, 1)
        XCTAssertEqual(VoicePlaybackRate.oneAndHalf.value, 1.5)
        XCTAssertEqual(VoicePlaybackRate.two.value, 2)
    }

    func testSendVoiceSignaturePassesDurationWaveformAndQuote() {
        let quote = Message(
            id: "q-1",
            senderID: "ada",
            sentAt: Date(),
            kind: .text("Already in my pocket.", preview: nil),
            isOutgoing: true
        )
        var captured: (URL, TimeInterval, [Float], Message?)?
        let actions = ConversationActions(onSendVoice: { url, duration, waveform, quoted in
            captured = (url, duration, waveform, quoted)
            return nil
        })
        let url = URL(fileURLWithPath: "/tmp/voice.m4a")
        _ = actions.onSendVoice?(url, 3.5, [0.2, 0.8], quote)
        XCTAssertEqual(captured?.0, url)
        XCTAssertEqual(captured?.1, 3.5)
        XCTAssertEqual(captured?.2, [0.2, 0.8])
        XCTAssertEqual(captured?.3?.id, "q-1")
    }

    func testChromeDismissStartsOnPlusPillCameraNotMicOrField() {
        let mic = UIView()
        let field = UITextView()
        let plus = UIButton()
        let camera = UIButton()
        let pill = UIView()
        XCTAssertTrue(ComposerChromeDismiss.allowsStart(hitView: plus, mic: mic, textView: field))
        XCTAssertTrue(ComposerChromeDismiss.allowsStart(hitView: camera, mic: mic, textView: field))
        XCTAssertTrue(ComposerChromeDismiss.allowsStart(hitView: pill, mic: mic, textView: field))
        XCTAssertFalse(ComposerChromeDismiss.allowsStart(hitView: mic, mic: mic, textView: field))
        XCTAssertFalse(ComposerChromeDismiss.allowsStart(hitView: field, mic: mic, textView: field))
        XCTAssertTrue(ComposerChromeDismiss.isVertical(translation: CGPoint(x: 0, y: 20), velocity: CGPoint(x: 4, y: 80)))
        XCTAssertFalse(ComposerChromeDismiss.isVertical(translation: CGPoint(x: 40, y: 2), velocity: CGPoint(x: 80, y: 4)))
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
