import Foundation

/// Looked up via `ConversationDataSource.participant(id:)`. Not stored on `Message`.
public struct Participant: Hashable, Sendable, Identifiable {
    public var id: UserID
    public var displayName: String
    public var avatar: ImageSource?
    public var nameColorToken: String?

    public init(
        id: UserID,
        displayName: String,
        avatar: ImageSource? = nil,
        nameColorToken: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.avatar = avatar
        self.nameColorToken = nameColorToken
    }
}
