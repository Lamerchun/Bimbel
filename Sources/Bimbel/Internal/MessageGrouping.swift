import Foundation

enum ChatSection: Hashable, Sendable {
    case thread
}

enum ChatRow: Hashable, Sendable {
    case date(Date)
    case unread
    case message(Message, MessageDecoration)
}

struct MessageDecoration: Hashable, Sendable {
    var cluster: ClusterPosition
    var mediaStack: MediaStackPosition
    var showsIncomingAvatar: Bool
    var incomingName: String?

    static let standalone = MessageDecoration(
        cluster: .standalone,
        mediaStack: .none,
        showsIncomingAvatar: false,
        incomingName: nil
    )
}

enum ClusterPosition: Hashable, Sendable {
    case standalone
    case first
    case middle
    case last

    var isFirstInCluster: Bool {
        self == .standalone || self == .first
    }

    var isLastInCluster: Bool {
        self == .standalone || self == .last
    }
}

enum MediaStackPosition: Hashable, Sendable {
    case none
    case first
    case middle
    case last

    var joinsTop: Bool {
        self == .middle || self == .last
    }

    var joinsBottom: Bool {
        self == .first || self == .middle
    }

    var isStacked: Bool {
        self != .none
    }
}

enum MessageGrouping {
    static func rows(
        from snapshot: ConversationSnapshot,
        calendar: Calendar = .current
    ) -> [ChatRow] {
        let messages = snapshot.messages.filter { !$0.id.isEmpty }
        guard !messages.isEmpty else { return [] }

        var decorated: [(Message, MessageDecoration)] = messages.map { ($0, .standalone) }
        let isGroup = Set(
            messages.filter { !$0.isOutgoing && !isSystem($0) }.map(\.senderID)
        ).count > 1

        for index in messages.indices {
            let message = messages[index]
            if isSystem(message) {
                decorated[index].1 = .standalone
                continue
            }

            let previous = index > 0 ? messages[index - 1] : nil
            let next = index + 1 < messages.count ? messages[index + 1] : nil
            let previousSame = previous.map { isSameCluster(message, $0, calendar: calendar) } ?? false
            let nextSame = next.map { isSameCluster(message, $0, calendar: calendar) } ?? false

            let cluster: ClusterPosition
            switch (previousSame, nextSame) {
            case (false, false): cluster = .standalone
            case (false, true): cluster = .first
            case (true, true): cluster = .middle
            case (true, false): cluster = .last
            }

            let stack = mediaStackPosition(
                at: index,
                messages: messages,
                calendar: calendar
            )

            // 1:1: avatar lives in the header, never on a transcript row.
            // Groups: incoming avatar only at the end of a sequence.
            let showsIncomingAvatar = isGroup && !message.isOutgoing && cluster.isLastInCluster
            decorated[index].1 = MessageDecoration(
                cluster: cluster,
                mediaStack: stack,
                showsIncomingAvatar: showsIncomingAvatar,
                incomingName: nil
            )
        }

        var rows: [ChatRow] = []
        var lastDay: Date?
        for (message, decoration) in decorated {
            let day = calendar.startOfDay(for: message.sentAt)
            if lastDay != day {
                rows.append(.date(day))
                lastDay = day
            }
            if message.id == snapshot.firstUnreadID {
                rows.append(.unread)
            }
            rows.append(.message(message, decoration))
        }
        return rows
    }

    static func isSystem(_ message: Message) -> Bool {
        if case .system = message.kind { return true }
        return false
    }

    static func isSameCluster(_ a: Message, _ b: Message, calendar: Calendar) -> Bool {
        guard !isSystem(a), !isSystem(b) else { return false }
        guard a.senderID == b.senderID, a.isOutgoing == b.isOutgoing else { return false }
        return calendar.isDate(a.sentAt, inSameDayAs: b.sentAt)
    }

    static func isMediaLike(_ message: Message) -> Bool {
        switch message.kind {
        case .image, .video, .document:
            return true
        case .text(_, let preview):
            return preview != nil
        case .voice, .system:
            return false
        }
    }

    /// Consecutive media/link (and trailing text after media) form one silhouette.
    /// Consecutive plain text does **not** flatten like iMessage — full rounding stays.
    static func mediaStackPosition(
        at index: Int,
        messages: [Message],
        calendar: Calendar
    ) -> MediaStackPosition {
        let message = messages[index]
        guard !isSystem(message) else { return .none }

        let previous = index > 0 ? messages[index - 1] : nil
        let next = index + 1 < messages.count ? messages[index + 1] : nil
        let previousJoin = previous.map {
            isSameCluster(message, $0, calendar: calendar) && shouldJoinMediaStack(message, $0)
        } ?? false
        let nextJoin = next.map {
            isSameCluster(message, $0, calendar: calendar) && shouldJoinMediaStack(message, $0)
        } ?? false

        switch (previousJoin, nextJoin) {
        case (false, false):
            return .none
        case (false, true):
            return .first
        case (true, true):
            return .middle
        case (true, false):
            return .last
        }
    }

    private static func shouldJoinMediaStack(_ a: Message, _ b: Message) -> Bool {
        // Join when at least one of the pair is media/link. Plain-text + plain-text stays unjoined.
        isMediaLike(a) || isMediaLike(b)
    }
}
