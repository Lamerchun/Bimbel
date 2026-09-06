import Foundation

/// All closures optional. The package never mints `ConversationID`s;
/// `onOpen` is the row tap. Read / pin / mute / delete / archive are host persistence.
public struct InboxActions {
    public var onOpen: ((ConversationID) -> Void)?
    public var onToggleRead: ((ConversationID) -> Void)?
    public var onTogglePin: ((ConversationID) -> Void)?
    public var onToggleMute: ((ConversationID) -> Void)?
    /// Alias for `onTogglePin`. Prefer `onTogglePin`.
    public var onPin: ((ConversationID) -> Void)?
    /// Alias for `onToggleMute`. Prefer `onToggleMute`.
    public var onMute: ((ConversationID) -> Void)?
    public var onDelete: ((ConversationID) -> Void)?
    public var onArchive: ((ConversationID) -> Void)?
    public var onSearch: ((String) -> Void)?
    public var onTitleTap: (() -> Void)?
    /// Long-press Archive is offered only when this is true or `onArchive` is set.
    public var supportsArchive: Bool

    public init(
        onOpen: ((ConversationID) -> Void)? = nil,
        onToggleRead: ((ConversationID) -> Void)? = nil,
        onTogglePin: ((ConversationID) -> Void)? = nil,
        onToggleMute: ((ConversationID) -> Void)? = nil,
        onPin: ((ConversationID) -> Void)? = nil,
        onMute: ((ConversationID) -> Void)? = nil,
        onDelete: ((ConversationID) -> Void)? = nil,
        onArchive: ((ConversationID) -> Void)? = nil,
        onSearch: ((String) -> Void)? = nil,
        onTitleTap: (() -> Void)? = nil,
        supportsArchive: Bool = false
    ) {
        self.onOpen = onOpen
        self.onToggleRead = onToggleRead
        self.onTogglePin = onTogglePin ?? onPin
        self.onToggleMute = onToggleMute ?? onMute
        self.onPin = onPin ?? onTogglePin
        self.onMute = onMute ?? onToggleMute
        self.onDelete = onDelete
        self.onArchive = onArchive
        self.onSearch = onSearch
        self.onTitleTap = onTitleTap
        self.supportsArchive = supportsArchive || onArchive != nil
    }

    var offersArchive: Bool { supportsArchive && onArchive != nil }

    func pin(_ id: ConversationID) {
        (onTogglePin ?? onPin)?(id)
    }

    func mute(_ id: ConversationID) {
        (onToggleMute ?? onMute)?(id)
    }
}
