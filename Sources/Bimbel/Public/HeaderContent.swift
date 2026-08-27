import Foundation

public struct HeaderContent: Hashable, Sendable {
    public var title: String
    public var subtitle: String?
    public var avatar: ImageSource?
    /// `nil` or `0` hides the badge. Values above 99 render as `99+`.
    public var unreadBadge: Int?
    public var showsVideo: Bool
    public var showsCall: Bool
    /// When true, Video+Call are replaced by a single unified call control. No overflow menu.
    public var showsUnifiedCall: Bool
    public var isTyping: Bool

    public init(
        title: String,
        subtitle: String? = nil,
        avatar: ImageSource? = nil,
        unreadBadge: Int? = nil,
        showsVideo: Bool = true,
        showsCall: Bool = true,
        showsUnifiedCall: Bool = false,
        isTyping: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatar = avatar
        self.unreadBadge = unreadBadge
        self.showsVideo = showsVideo
        self.showsCall = showsCall
        self.showsUnifiedCall = showsUnifiedCall
        self.isTyping = isTyping
    }
}
