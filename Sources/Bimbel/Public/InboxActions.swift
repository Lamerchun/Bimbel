import Foundation

/// All closures optional. The package never mints `ConversationID`s;
/// `onOpen` is the row tap. Pin / mute / delete are host persistence.
public struct InboxActions {
    public var onOpen: ((ConversationID) -> Void)?
    public var onPin: ((ConversationID) -> Void)?
    public var onMute: ((ConversationID) -> Void)?
    public var onDelete: ((ConversationID) -> Void)?
    public var onSearch: ((String) -> Void)?
    public var onTitleTap: (() -> Void)?

    public init(
        onOpen: ((ConversationID) -> Void)? = nil,
        onPin: ((ConversationID) -> Void)? = nil,
        onMute: ((ConversationID) -> Void)? = nil,
        onDelete: ((ConversationID) -> Void)? = nil,
        onSearch: ((String) -> Void)? = nil,
        onTitleTap: (() -> Void)? = nil
    ) {
        self.onOpen = onOpen
        self.onPin = onPin
        self.onMute = onMute
        self.onDelete = onDelete
        self.onSearch = onSearch
        self.onTitleTap = onTitleTap
    }
}
