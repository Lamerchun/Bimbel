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
    var reservesIncomingAvatarGutter: Bool
    var showsIncomingName: Bool
    var showsFooter: Bool

    static let standalone = MessageDecoration(
        cluster: .standalone,
        mediaStack: .none,
        showsIncomingAvatar: false,
        reservesIncomingAvatarGutter: false,
        showsIncomingName: false,
        showsFooter: true
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
        maxGap: TimeInterval = ConversationTheme.Grouping.bimbel.maxGap,
        calendar: Calendar = .current
    ) -> [ChatRow] {
        let messages = expandCaptions(snapshot.messages.filter { !$0.id.isEmpty })
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

            let previous = previousMessage(before: index, in: messages)
            let next = nextMessage(after: index, in: messages)
            let previousSame = previous.map {
                isSameCluster(message, $0, maxGap: maxGap, calendar: calendar)
            } ?? false
            let nextSame = next.map {
                isSameCluster(message, $0, maxGap: maxGap, calendar: calendar)
            } ?? false

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
                maxGap: maxGap,
                calendar: calendar
            )

            let authorChanged: Bool
            if let previous, !isSystem(previous) {
                authorChanged = previous.senderID != message.senderID
            } else {
                authorChanged = true
            }
            decorated[index].1 = MessageDecoration(
                cluster: cluster,
                mediaStack: stack,
                showsIncomingAvatar: isGroup && !message.isOutgoing && cluster.isLastInCluster,
                reservesIncomingAvatarGutter: isGroup && !message.isOutgoing,
                showsIncomingName: isGroup && !message.isOutgoing && authorChanged,
                showsFooter: showsFooter(current: message, next: next, calendar: calendar)
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

    /// Same direction; groups also same author (always compared). Window is `maxGap`,
    /// not media-stack / album spacing.
    static func isSameCluster(
        _ a: Message,
        _ b: Message,
        maxGap: TimeInterval = ConversationTheme.Grouping.bimbel.maxGap,
        calendar: Calendar = .current
    ) -> Bool {
        guard !isSystem(a), !isSystem(b) else { return false }
        guard a.isOutgoing == b.isOutgoing else { return false }
        guard a.senderID == b.senderID else { return false }
        guard calendar.isDate(a.sentAt, inSameDayAs: b.sentAt) else { return false }
        return abs(a.sentAt.timeIntervalSince(b.sentAt)) <= maxGap
    }

    /// Hide the timestamp when the next message cell shares the short clock
    /// and outgoing status. Sending / failed / edited always keep a footer.
    static func showsFooter(
        current: Message,
        next: Message?,
        calendar: Calendar = .current
    ) -> Bool {
        if current.delivery == .sending || current.delivery == .failed { return true }
        if current.editedAt != nil { return true }
        guard let next, !isSystem(next) else { return true }
        guard calendar.isDate(current.sentAt, inSameDayAs: next.sentAt) else { return true }
        guard shortTime(current.sentAt) == shortTime(next.sentAt) else { return true }
        return !sameOutgoingStatus(current, next)
    }

    static func shortTime(_ date: Date) -> String {
        BimbelFormatters.messageTime.string(from: date)
    }

    static func sameOutgoingStatus(_ a: Message, _ b: Message) -> Bool {
        guard a.isOutgoing == b.isOutgoing else { return false }
        if a.isOutgoing { return a.delivery == b.delivery }
        return true
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
    /// Consecutive plain text does **not** flatten. Uses the cluster window, not album gap.
    static func mediaStackPosition(
        at index: Int,
        messages: [Message],
        maxGap: TimeInterval = ConversationTheme.Grouping.bimbel.maxGap,
        calendar: Calendar = .current
    ) -> MediaStackPosition {
        let message = messages[index]
        guard !isSystem(message) else { return .none }

        let previous = index > 0 ? messages[index - 1] : nil
        let next = index + 1 < messages.count ? messages[index + 1] : nil
        let previousJoin = previous.map {
            isSameCluster(message, $0, maxGap: maxGap, calendar: calendar) && shouldJoinMediaStack(message, $0)
        } ?? false
        let nextJoin = next.map {
            isSameCluster(message, $0, maxGap: maxGap, calendar: calendar) && shouldJoinMediaStack(message, $0)
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

    private static func previousMessage(before index: Int, in messages: [Message]) -> Message? {
        guard index > 0 else { return nil }
        return messages[index - 1]
    }

    private static func nextMessage(after index: Int, in messages: [Message]) -> Message? {
        let next = index + 1
        guard next < messages.count else { return nil }
        return messages[next]
    }

    private static func shouldJoinMediaStack(_ a: Message, _ b: Message) -> Bool {
        // Join when at least one of the pair is media/link. Plain-text + plain-text stays unjoined.
        isMediaLike(a) || isMediaLike(b)
    }

    /// Captions are a following text bubble in the media stack, never a footer on the image.
    static func expandCaptions(_ messages: [Message]) -> [Message] {
        var expanded: [Message] = []
        expanded.reserveCapacity(messages.count)
        for message in messages {
            switch message.kind {
            case .image(var media) where caption(media.caption) != nil:
                let text = caption(media.caption)!
                media.caption = nil
                var image = message
                image.kind = .image(media)
                expanded.append(image)
                expanded.append(captionMessage(from: message, text: text))
            case .video(var media) where caption(media.caption) != nil:
                let text = caption(media.caption)!
                media.caption = nil
                var video = message
                video.kind = .video(media)
                expanded.append(video)
                expanded.append(captionMessage(from: message, text: text))
            default:
                expanded.append(message)
            }
        }
        return expanded
    }

    private static func caption(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func captionMessage(from message: Message, text: String) -> Message {
        Message(
            id: "\(message.id)#caption",
            senderID: message.senderID,
            sentAt: message.sentAt,
            kind: .text(text, preview: nil),
            replyTo: message.replyTo,
            reactions: [],
            delivery: message.delivery,
            editedAt: message.editedAt,
            isOutgoing: message.isOutgoing
        )
    }
}
