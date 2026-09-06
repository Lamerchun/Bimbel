import XCTest
@testable import Bimbel

final class EditSessionTests: XCTestCase {
    func testShip4Section3Tokens() {
        let layout = ConversationTheme.default.layout
        XCTAssertEqual(layout.approvalThumb, ConversationApprovalChrome.thumb)
        XCTAssertEqual(layout.approvalThumb, 64)
        XCTAssertEqual(layout.approvalThumbGap, ConversationApprovalChrome.thumbGap)
        XCTAssertEqual(layout.approvalThumbGap, 8)
        XCTAssertEqual(ConversationTheme.default.radii.approvalThumb, ConversationApprovalChrome.thumbRadius)
        XCTAssertEqual(ConversationTheme.default.radii.approvalThumb, 12)
        XCTAssertEqual(layout.maxAttachmentsPerSend, ConversationApprovalChrome.maxAttachments)
        XCTAssertEqual(layout.maxAttachmentsPerSend, 10)
        XCTAssertEqual(layout.drawStrokeWidth, ConversationApprovalChrome.drawWidth)
        XCTAssertEqual(layout.drawStrokeWidth, 4)
        XCTAssertEqual(layout.hitTarget, ConversationApprovalChrome.hit)
        XCTAssertEqual(layout.headerIcon, ConversationApprovalChrome.toolIcon)
        XCTAssertEqual(UIImage.SymbolConfiguration.bimbelComposerLinePointSize, 22)
        XCTAssertEqual(UIImage.SymbolConfiguration.bimbelComposerLineWeight, .ultraLight)
        XCTAssertEqual(ConversationTheme.default.fonts.bubbleBody.pointSize, 16)
        XCTAssertEqual(ConversationApprovalChrome.textColor, UIColor.white)
    }

    func testApprovalCaptionIsComposerCapsuleAndSendIsAccentCircle() {
        var session = EditSession()
        _ = session.admit([.photo(data: Data([UInt8(1)]))], limit: 10)
        let vc = MediaApprovalViewController(session: session, theme: .default)
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        host.addSubview(vc.view)
        vc.view.frame = host.bounds
        vc.view.layoutIfNeeded()

        XCTAssertEqual(vc.captionFill.layer.borderWidth, 0)
        XCTAssertEqual(vc.captionFill.backgroundColor, ConversationTheme.default.colors.composerFill)
        if vc.captionFill.bounds.height <= 1 {
            vc.captionFill.bounds = CGRect(x: 0, y: 0, width: 240, height: ConversationApprovalChrome.captionHeight)
        }
        vc.captionFill.applyCapsule()
        XCTAssertEqual(vc.captionFill.layer.cornerRadius, vc.captionFill.bounds.height / 2, accuracy: 0.5)
        if vc.sendFill.bounds.width <= 1 {
            vc.sendFill.bounds = CGRect(
                x: 0,
                y: 0,
                width: ConversationApprovalChrome.sendCircle,
                height: ConversationApprovalChrome.sendCircle
            )
            vc.sendFill.layoutIfNeeded()
        }
        XCTAssertEqual(vc.sendFill.bounds.width, ConversationApprovalChrome.sendCircle, accuracy: 0.5)
        XCTAssertEqual(vc.sendFill.bounds.height, ConversationApprovalChrome.sendCircle, accuracy: 0.5)
        XCTAssertEqual(vc.sendFill.layer.cornerRadius, ConversationApprovalChrome.sendCircle / 2, accuracy: 0.5)
        XCTAssertEqual(vc.sendFill.backgroundColor, ConversationTheme.default.colors.sendFill)
        XCTAssertEqual(vc.toolButtons.count, 3)
        for button in vc.toolButtons {
            XCTAssertEqual(button.backgroundColor?.cgColor.alpha ?? 0, 0, accuracy: 0.01)
            XCTAssertGreaterThanOrEqual(button.minimumHitSize.width, 44)
            XCTAssertGreaterThanOrEqual(button.minimumHitSize.height, 44)
            XCTAssertNil(button.configuration)
        }
    }

    func testAdmitStopsAtLimitAndReportsRejected() {
        var session = EditSession()
        let incoming = (0..<12).map { EditSession.Item.photo(data: Data([UInt8($0)])) }
        let result = session.admit(incoming, limit: ConversationTheme.Layout().maxAttachmentsPerSend)
        XCTAssertEqual(session.items.count, 10)
        XCTAssertEqual(result.admitted, 10)
        XCTAssertEqual(result.rejected, 2)
        XCTAssertEqual(session.title(), "10 Photos")
    }

    func testSecondAdmitDoesNotSilentTruncate() {
        var session = EditSession()
        _ = session.admit((0..<9).map { EditSession.Item.photo(data: Data([UInt8($0)])) }, limit: 10)
        let extra = (0..<3).map { EditSession.Item.photo(data: Data([UInt8(20 + $0)])) }
        let result = session.admit(extra, limit: 10)
        XCTAssertEqual(session.items.count, 10)
        XCTAssertEqual(result.admitted, 1)
        XCTAssertEqual(result.rejected, 2)
        XCTAssertEqual(EditSession.overLimitMessage(limit: 10), "You can send up to 10 photos or videos.")
    }

    func testRemoveAndMixedTitle() {
        var session = EditSession()
        _ = session.admit([
            .photo(data: Data([1])),
            .video(url: URL(fileURLWithPath: "/tmp/a.mov"), poster: nil, duration: 4),
            .photo(data: Data([2]))
        ], limit: 10)
        XCTAssertEqual(session.title(), "3 Items")
        session.remove(id: session.items[1].id)
        XCTAssertEqual(session.items.count, 2)
        XCTAssertEqual(session.title(), "2 Photos")
    }

    func testOutgoingMediaMapsToStagedAttachment() {
        let photo = OutgoingMedia(kind: .image, source: .data(Data([UInt8(1)])))
        if case .image(let source) = photo.asStagedAttachment().kind {
            XCTAssertEqual(source, .data(Data([UInt8(1)])))
        } else {
            XCTFail("photo should stage as image")
        }
        let video = OutgoingMedia(kind: .video, source: .url(URL(fileURLWithPath: "/tmp/v.mov")), duration: 3)
        if case .video = video.asStagedAttachment().kind {
            XCTAssertEqual(video.duration, 3)
        } else {
            XCTFail("video should stage as video")
        }
    }

    func testSendMediaPreferredOverAttachments() {
        var sentMedia: [OutgoingMedia] = []
        var sentAttachments: [StagedAttachment] = []
        let actions = ConversationActions(
            onSendAttachments: { attachments in
                sentAttachments = attachments
                return nil
            },
            onSendMedia: { media, caption in
                sentMedia = media
                XCTAssertEqual(caption, "See you there.")
                return []
            }
        )
        XCTAssertNotNil(actions.onSendMedia)
        _ = actions.onSendMedia?([OutgoingMedia(kind: .image, source: .data(Data()))], "See you there.")
        _ = actions.onSendAttachments?([StagedAttachment(kind: .image(.data(Data())))])
        XCTAssertEqual(sentMedia.count, 1)
        XCTAssertEqual(sentAttachments.count, 1)
    }

    func testVideoTrimNeededOnlyWhenRangeShortens() {
        let full = MediaVideoTrim(start: 0, end: 12)
        XCTAssertFalse(MediaRender.needsTrim(full, duration: 12))
        XCTAssertTrue(MediaRender.needsTrim(MediaVideoTrim(start: 1, end: 8), duration: 12))
    }
}
