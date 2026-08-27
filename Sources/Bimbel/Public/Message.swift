import Foundation

public struct Media: Hashable, Sendable {
    public var source: ImageSource
    public var width: Int?
    public var height: Int?
    public var caption: String?
    public var duration: TimeInterval?

    public init(
        source: ImageSource,
        width: Int? = nil,
        height: Int? = nil,
        caption: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.source = source
        self.width = width
        self.height = height
        self.caption = caption
        self.duration = duration
    }
}

public struct Voice: Hashable, Sendable {
    public var duration: TimeInterval
    public var waveform: [Float]
    public var fileURL: URL?

    public init(duration: TimeInterval, waveform: [Float] = [], fileURL: URL? = nil) {
        self.duration = duration
        self.waveform = waveform
        self.fileURL = fileURL
    }
}

public struct Document: Hashable, Sendable {
    public var name: String
    public var byteCount: Int64
    public var fileURL: URL?
    public var mimeType: String?

    public init(name: String, byteCount: Int64, fileURL: URL? = nil, mimeType: String? = nil) {
        self.name = name
        self.byteCount = byteCount
        self.fileURL = fileURL
        self.mimeType = mimeType
    }
}

public struct LinkPreview: Hashable, Sendable {
    public var url: URL
    public var title: String?
    public var summary: String?
    public var siteName: String?
    public var thumbnail: ImageSource?

    public init(
        url: URL,
        title: String? = nil,
        summary: String? = nil,
        siteName: String? = nil,
        thumbnail: ImageSource? = nil
    ) {
        self.url = url
        self.title = title
        self.summary = summary
        self.siteName = siteName
        self.thumbnail = thumbnail
    }
}

/// Link previews live on `text`, not as their own kind.
public enum MessageKind: Hashable, Sendable {
    case text(String, preview: LinkPreview?)
    case image(Media)
    case video(Media)
    case voice(Voice)
    case document(Document)
    case system(String)
}

public enum DeliveryState: Hashable, Sendable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

public struct Reaction: Hashable, Sendable {
    public var emoji: String
    public var userIDs: [UserID]

    public init(emoji: String, userIDs: [UserID]) {
        self.emoji = emoji
        self.userIDs = userIDs
    }
}

public struct Message: Hashable, Sendable, Identifiable {
    public var id: MessageID
    public var senderID: UserID
    public var sentAt: Date
    public var kind: MessageKind
    public var replyTo: MessageID?
    public var reactions: [Reaction]
    public var delivery: DeliveryState
    public var isEdited: Bool
    public var isOutgoing: Bool

    public init(
        id: MessageID,
        senderID: UserID,
        sentAt: Date,
        kind: MessageKind,
        replyTo: MessageID? = nil,
        reactions: [Reaction] = [],
        delivery: DeliveryState = .sent,
        isEdited: Bool = false,
        isOutgoing: Bool
    ) {
        self.id = id
        self.senderID = senderID
        self.sentAt = sentAt
        self.kind = kind
        self.replyTo = replyTo
        self.reactions = reactions
        self.delivery = delivery
        self.isEdited = isEdited
        self.isOutgoing = isOutgoing
    }
}
