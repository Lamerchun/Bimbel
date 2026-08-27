import Foundation

public struct ConversationSnapshot: Hashable, Sendable {
    public var conversationID: ConversationID
    public var messages: [Message]
    public var firstUnreadID: MessageID?

    public init(
        conversationID: ConversationID,
        messages: [Message],
        firstUnreadID: MessageID? = nil
    ) {
        self.conversationID = conversationID
        self.messages = messages
        self.firstUnreadID = firstUnreadID
    }
}
