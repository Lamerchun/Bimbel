import Foundation
import CoreLocation

/// All closures are optional. Empty `ConversationActions()` is a valid host.
///
/// `onSendText` / `onSendAttachments` / `onSendVoice` return `Message?`:
/// - non-nil: the package inserts that message via `apply`
/// - nil: the host already pushed a snapshot
/// The package never mints message IDs.
public struct ConversationActions {
    public var onBack: (() -> Void)?
    public var onHeaderTap: (() -> Void)?
    public var onVideo: (() -> Void)?
    public var onCall: (() -> Void)?
    public var onSendText: ((String) -> Message?)?
    public var onSendAttachments: (([StagedAttachment]) -> Message?)?
    public var onSendVoice: ((URL) -> Message?)?
    public var onReply: ((Message) -> Void)?
    public var onReaction: ((Message, String) -> Void)?
    public var onForward: (([Message]) -> Void)?
    public var onDeleteMessages: (([Message]) -> Void)?
    public var onSaveMedia: ((Message) -> Void)?
    /// Edit-Gate. Edit appears only when this returns true.
    public var canEdit: ((Message) -> Bool)?
    /// Host-owned editor. Media Crop/Draw/Text is Ship 4 — this pass only calls through.
    public var onEdit: ((Message) -> Void)?
    public var onOpenURL: ((URL) -> Void)?
    public var onAttachmentAction: ((AttachmentAction) -> Void)?
    public var onRequestLocation: (() -> CLLocationCoordinate2D?)?

    public init(
        onBack: (() -> Void)? = nil,
        onHeaderTap: (() -> Void)? = nil,
        onVideo: (() -> Void)? = nil,
        onCall: (() -> Void)? = nil,
        onSendText: ((String) -> Message?)? = nil,
        onSendAttachments: (([StagedAttachment]) -> Message?)? = nil,
        onSendVoice: ((URL) -> Message?)? = nil,
        onReply: ((Message) -> Void)? = nil,
        onReaction: ((Message, String) -> Void)? = nil,
        onForward: (([Message]) -> Void)? = nil,
        onDeleteMessages: (([Message]) -> Void)? = nil,
        onSaveMedia: ((Message) -> Void)? = nil,
        canEdit: ((Message) -> Bool)? = nil,
        onEdit: ((Message) -> Void)? = nil,
        onOpenURL: ((URL) -> Void)? = nil,
        onAttachmentAction: ((AttachmentAction) -> Void)? = nil,
        onRequestLocation: (() -> CLLocationCoordinate2D?)? = nil
    ) {
        self.onBack = onBack
        self.onHeaderTap = onHeaderTap
        self.onVideo = onVideo
        self.onCall = onCall
        self.onSendText = onSendText
        self.onSendAttachments = onSendAttachments
        self.onSendVoice = onSendVoice
        self.onReply = onReply
        self.onReaction = onReaction
        self.onForward = onForward
        self.onDeleteMessages = onDeleteMessages
        self.onSaveMedia = onSaveMedia
        self.canEdit = canEdit
        self.onEdit = onEdit
        self.onOpenURL = onOpenURL
        self.onAttachmentAction = onAttachmentAction
        self.onRequestLocation = onRequestLocation
    }

    func allowsEdit(_ message: Message) -> Bool {
        canEdit?(message) ?? false
    }
}
