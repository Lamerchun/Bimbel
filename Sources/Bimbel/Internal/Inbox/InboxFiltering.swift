import Foundation

enum InboxListSection: Int, Hashable {
    case pinned
    case chats
}

enum InboxFiltering {
    static func visible(items: [InboxItem], query: String, unreadOnly: Bool) -> [InboxItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            if unreadOnly, !item.showsUnread { return false }
            guard !trimmed.isEmpty else { return true }
            return matchesSearch(item, query: trimmed)
        }
    }

    /// Title and participant names only. Preview body is not a search field.
    static func matchesSearch(_ item: InboxItem, query: String) -> Bool {
        if item.title.localizedCaseInsensitiveContains(query) { return true }
        return item.participantNames.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    static func sections(
        items: [InboxItem],
        query: String,
        unreadOnly: Bool
    ) -> (pinned: [InboxItem], chats: [InboxItem]) {
        let visible = visible(items: items, query: query, unreadOnly: unreadOnly)
        return (
            pinned: visible.filter(\.isPinned),
            chats: visible.filter { !$0.isPinned }
        )
    }
}

enum InboxRowActionCatalog {
    static func leadingTitles(for item: InboxItem) -> [String] {
        [
            item.showsUnread ? String(localized: "Read") : String(localized: "Unread"),
            item.isPinned ? String(localized: "Unpin") : String(localized: "Pin")
        ]
    }

    static func trailingTitles(for item: InboxItem) -> [String] {
        [
            item.isMuted ? String(localized: "Unmute") : String(localized: "Mute"),
            String(localized: "Delete")
        ]
    }

    static func menuTitles(for item: InboxItem, supportsArchive: Bool) -> [String] {
        var titles = leadingTitles(for: item)
        titles.append(item.isMuted ? String(localized: "Unmute") : String(localized: "Mute"))
        if supportsArchive {
            titles.append(String(localized: "Archive"))
        }
        titles.append(String(localized: "Delete"))
        return titles
    }
}
