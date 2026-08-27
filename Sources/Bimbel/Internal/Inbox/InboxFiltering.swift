import Foundation

enum InboxFiltering {
    static func visible(items: [InboxItem], query: String, unreadOnly: Bool) -> [InboxItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            if unreadOnly, item.unreadCount <= 0 { return false }
            guard !trimmed.isEmpty else { return true }
            return item.title.localizedCaseInsensitiveContains(trimmed)
                || item.preview.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
