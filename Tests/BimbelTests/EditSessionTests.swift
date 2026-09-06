import XCTest
@testable import Bimbel

final class EditSessionTests: XCTestCase {
    func testShip4ApprovalTokens() {
        let layout = ConversationTheme.default.layout
        XCTAssertEqual(layout.maxAttachmentsPerSend, 10)
        XCTAssertEqual(layout.approvalThumb, 64)
        XCTAssertEqual(layout.approvalThumbGap, 8)
        XCTAssertEqual(layout.headerIcon, 22)
        XCTAssertEqual(layout.drawStrokeWidth, 4)
        XCTAssertEqual(ConversationTheme.default.radii.approvalThumb, 12)
        XCTAssertEqual(ConversationTheme.default.radii.composerPill, 24)
        XCTAssertEqual(ConversationTheme.default.fonts.bubbleBody.pointSize, 16)
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
