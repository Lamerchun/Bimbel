import XCTest
@testable import Bimbel

final class InboxPreviewResolverTests: XCTestCase {
    func testOverrideWinsOverDraftAndBody() {
        let item = InboxItem(
            id: "a",
            title: "Ada",
            preview: "On my way.",
            timestamp: Date(),
            previewOverride: "Waiting for a reply.",
            draftPreview: .text("Ask about Saturday"),
            previewSenderName: "Mira"
        )
        XCTAssertEqual(InboxPreviewResolver.kind(for: item), .override("Waiting for a reply."))
    }

    func testDraftWinsOverGroupAndBody() {
        let item = InboxItem(
            id: "a",
            title: "Design",
            preview: "Moodboard is in the shared folder.",
            timestamp: Date(),
            isGroup: true,
            draftPreview: .text("Ask about Saturday"),
            previewSenderName: "Mira"
        )
        XCTAssertEqual(InboxPreviewResolver.kind(for: item), .draftText("Ask about Saturday"))
    }

    func testVoiceDraftKind() {
        let item = InboxItem(
            id: "a",
            title: "Kai",
            preview: "Saturday still work?",
            timestamp: Date(),
            draftPreview: .voice
        )
        XCTAssertEqual(InboxPreviewResolver.kind(for: item), .draftVoice)
    }

    func testGroupSenderPrefixWinsOverBareBody() {
        let item = InboxItem(
            id: "g",
            title: "Design",
            preview: "Moodboard is in the shared folder.",
            timestamp: Date(),
            isGroup: true,
            previewSenderName: "Mira"
        )
        XCTAssertEqual(
            InboxPreviewResolver.kind(for: item),
            .group(sender: "Mira", body: "Moodboard is in the shared folder.")
        )
    }

    func testTypingReplacesBodyWhenNoOverrideOrDraft() {
        let item = InboxItem(
            id: "m",
            title: "Mira",
            preview: "Did you lock the studio?",
            timestamp: Date(),
            isTyping: true
        )
        XCTAssertEqual(InboxPreviewResolver.kind(for: item), .typing)
    }

    func testOutgoingStatusOnlyForHostLastMessageBody() {
        var outgoing = InboxItem(
            id: "a",
            title: "Ada",
            preview: "On my way.",
            timestamp: Date(),
            lastOutgoingDelivery: .read
        )
        XCTAssertTrue(InboxPreviewResolver.showsOutgoingStatus(for: outgoing))

        outgoing.draftPreview = .text("Ask about Saturday")
        XCTAssertFalse(InboxPreviewResolver.showsOutgoingStatus(for: outgoing))

        let incoming = InboxItem(
            id: "j",
            title: "Jules",
            preview: "Call me when you land.",
            timestamp: Date()
        )
        XCTAssertFalse(InboxPreviewResolver.showsOutgoingStatus(for: incoming))

        let group = InboxItem(
            id: "g",
            title: "Design",
            preview: "Moodboard is in the shared folder.",
            timestamp: Date(),
            previewSenderName: "Mira",
            lastOutgoingDelivery: .sent
        )
        XCTAssertFalse(InboxPreviewResolver.showsOutgoingStatus(for: group))
    }

    func testAttributedDraftAndGroupCopy() {
        let draft = InboxItem(
            id: "k",
            title: "Kai",
            preview: "Saturday still work?",
            timestamp: Date(),
            draftPreview: .text("Ask about Saturday")
        )
        let draftText = InboxPreviewResolver.attributedPreview(for: draft, theme: .default).string
        XCTAssertTrue(draftText.hasPrefix("Draft:"))
        XCTAssertTrue(draftText.contains("Ask about Saturday"))

        let attributed = InboxPreviewResolver.attributedPreview(for: draft, theme: .default)
        var prefixRange = NSRange(location: 0, length: 0)
        let prefixColor = attributed.attribute(.foregroundColor, at: 0, effectiveRange: &prefixRange) as? UIColor
        XCTAssertEqual(prefixColor, ConversationTheme.default.colors.inboxDraft)
        XCTAssertEqual(prefixColor, UIColor.secondaryLabel)
        XCTAssertNotEqual(prefixColor, ConversationTheme.default.colors.accent)
        let prefixFont = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(prefixFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)

        let group = InboxItem(
            id: "g",
            title: "Design",
            preview: "Moodboard is in the shared folder.",
            timestamp: Date(),
            previewSenderName: "Mira"
        )
        XCTAssertEqual(
            InboxPreviewResolver.attributedPreview(for: group, theme: .default).string,
            "Mira: Moodboard is in the shared folder."
        )
    }
}
