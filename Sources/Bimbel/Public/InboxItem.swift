import Foundation

/// Last unsent composer content for an inbox row. Wins over the last-message body.
public enum InboxDraftPreview: Hashable, Sendable {
    case text(String)
    case voice
}

/// Short type labels when the last message is an attachment, not a caption.
public enum InboxAttachmentLabel {
    public static var photo: String { String(localized: "Photo") }
    public static var video: String { String(localized: "Video") }
    public static var voice: String { String(localized: "Voice") }
    public static var document: String { String(localized: "Document") }
    public static var location: String { String(localized: "Location") }
    public static var contact: String { String(localized: "Contact") }
}

public struct InboxItem: Identifiable, Hashable, Sendable {
    public var id: ConversationID
    public var title: String
    public var preview: String
    public var timestamp: Date
    public var avatar: ImageSource?
    /// Count for the unread pill. `0` with `markedUnread` shows an empty dot instead.
    public var unreadCount: Int
    /// Host-marked unread with no count. Ignored when `unreadCount > 0`.
    public var markedUnread: Bool
    public var isPinned: Bool
    public var isMuted: Bool
    public var isTyping: Bool
    public var isGroup: Bool
    /// Host copy such as a request or block notice. Highest preview priority.
    public var previewOverride: String?
    public var draftPreview: InboxDraftPreview?
    /// Group last-sender display name. Renders as `Sender:` before the body.
    public var previewSenderName: String?
    /// Set only when the preview is the host’s own last message.
    public var lastOutgoingDelivery: DeliveryState?
    /// Search V1 matches `title` and these names, not the preview body.
    public var participantNames: [String]

    public init(
        id: ConversationID,
        title: String,
        preview: String,
        timestamp: Date,
        avatar: ImageSource? = nil,
        unreadCount: Int = 0,
        markedUnread: Bool = false,
        isPinned: Bool = false,
        isMuted: Bool = false,
        isTyping: Bool = false,
        isGroup: Bool = false,
        previewOverride: String? = nil,
        draftPreview: InboxDraftPreview? = nil,
        previewSenderName: String? = nil,
        lastOutgoingDelivery: DeliveryState? = nil,
        participantNames: [String] = []
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.timestamp = timestamp
        self.avatar = avatar
        self.unreadCount = unreadCount
        self.markedUnread = markedUnread
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isTyping = isTyping
        self.isGroup = isGroup
        self.previewOverride = previewOverride
        self.draftPreview = draftPreview
        self.previewSenderName = previewSenderName
        self.lastOutgoingDelivery = lastOutgoingDelivery
        self.participantNames = participantNames
    }

    public var showsUnread: Bool {
        unreadCount > 0 || markedUnread
    }
}
