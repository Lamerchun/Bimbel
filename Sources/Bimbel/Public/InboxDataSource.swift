import Foundation

@MainActor
public protocol InboxDataSource: AnyObject {
    func snapshot() -> InboxSnapshot
}
