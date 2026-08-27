import Foundation

@MainActor
public protocol ConversationDataSource: AnyObject {
    func snapshot(in conversationID: ConversationID) -> ConversationSnapshot
    func loadOlder(in conversationID: ConversationID) async throws -> ConversationSnapshot
    func participant(id: UserID) -> Participant?
}
