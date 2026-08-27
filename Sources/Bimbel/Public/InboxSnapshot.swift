import Foundation

public struct InboxSnapshot: Hashable, Sendable {
    public var items: [InboxItem]

    public init(items: [InboxItem]) {
        self.items = items
    }
}
