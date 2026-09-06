import Foundation

enum MediaPagerItems {
    static func collect(_ messages: [Message]) -> [Message] {
        messages.filter { ConversationMessageMenu.isMedia($0) }
    }

    static func startIndex(in items: [Message], id: MessageID) -> Int {
        items.firstIndex { $0.id == id } ?? 0
    }
}
