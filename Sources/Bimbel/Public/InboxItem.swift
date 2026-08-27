import Foundation

public struct InboxItem: Identifiable, Hashable, Sendable {
    public var id: ConversationID
    public var title: String
    public var preview: String
    public var timestamp: Date
    public var avatar: ImageSource?
    public var unreadCount: Int
    public var isPinned: Bool
    public var isMuted: Bool
    public var isTyping: Bool
    public var isGroup: Bool

    public init(
        id: ConversationID,
        title: String,
        preview: String,
        timestamp: Date,
        avatar: ImageSource? = nil,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false,
        isTyping: Bool = false,
        isGroup: Bool = false
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.timestamp = timestamp
        self.avatar = avatar
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isTyping = isTyping
        self.isGroup = isGroup
    }
}
