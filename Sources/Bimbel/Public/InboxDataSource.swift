import Foundation

/// Host-owned inbox rows. Push a new snapshot when any row field changes.
/// The package never mints `ConversationID`s.
@MainActor
public protocol InboxDataSource: AnyObject {
    func snapshot() -> InboxSnapshot
}
