import Foundation
import CoreGraphics

/// Approved media after `EditSession`. Camera and picker never send a raw image.
public struct OutgoingMedia: Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: Kind
    public var source: ImageSource
    public var width: Int?
    public var height: Int?
    public var duration: TimeInterval?

    public enum Kind: Hashable, Sendable {
        case image
        case video
    }

    public init(
        id: String = UUID().uuidString,
        kind: Kind,
        source: ImageSource,
        width: Int? = nil,
        height: Int? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.width = width
        self.height = height
        self.duration = duration
    }

    public func asStagedAttachment() -> StagedAttachment {
        switch kind {
        case .image: StagedAttachment(id: id, kind: .image(source))
        case .video: StagedAttachment(id: id, kind: .video(source))
        }
    }
}

public struct MediaCrop: Hashable, Sendable {
    public var normalizedRect: CGRect
    public var rotationQuarterTurns: Int

    public static let identity = MediaCrop(
        normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1),
        rotationQuarterTurns: 0
    )

    public init(normalizedRect: CGRect, rotationQuarterTurns: Int = 0) {
        self.normalizedRect = normalizedRect
        self.rotationQuarterTurns = rotationQuarterTurns
    }
}

public struct MediaStroke: Hashable, Sendable {
    public var points: [CGPoint]
    public var width: CGFloat

    public init(points: [CGPoint], width: CGFloat) {
        self.points = points
        self.width = width
    }
}

public struct MediaTextOverlay: Hashable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var normalizedCenter: CGPoint

    public init(
        id: String = UUID().uuidString,
        text: String,
        normalizedCenter: CGPoint
    ) {
        self.id = id
        self.text = text
        self.normalizedCenter = normalizedCenter
    }
}

public struct MediaVideoTrim: Hashable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }
}

/// Working set for Approval. Admit through here — never send camera/picker bytes raw.
public struct EditSession: Hashable, Sendable {
    public var items: [Item]
    public var caption: String
    public var selectedIndex: Int

    public struct Item: Hashable, Sendable, Identifiable {
        public var id: String
        public var kind: OutgoingMedia.Kind
        public var original: ImageSource
        public var crop: MediaCrop
        public var strokes: [MediaStroke]
        public var texts: [MediaTextOverlay]
        public var videoURL: URL?
        public var trim: MediaVideoTrim?
        public var pixelWidth: Int?
        public var pixelHeight: Int?
        public var duration: TimeInterval?

        public init(
            id: String = UUID().uuidString,
            kind: OutgoingMedia.Kind,
            original: ImageSource,
            crop: MediaCrop = .identity,
            strokes: [MediaStroke] = [],
            texts: [MediaTextOverlay] = [],
            videoURL: URL? = nil,
            trim: MediaVideoTrim? = nil,
            pixelWidth: Int? = nil,
            pixelHeight: Int? = nil,
            duration: TimeInterval? = nil
        ) {
            self.id = id
            self.kind = kind
            self.original = original
            self.crop = crop
            self.strokes = strokes
            self.texts = texts
            self.videoURL = videoURL
            self.trim = trim
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.duration = duration
        }

        public static func photo(data: Data, width: Int? = nil, height: Int? = nil) -> Item {
            Item(kind: .image, original: .data(data), pixelWidth: width, pixelHeight: height)
        }

        public static func video(url: URL, poster: Data?, duration: TimeInterval) -> Item {
            Item(
                kind: .video,
                original: poster.map { .data($0) } ?? .url(url),
                videoURL: url,
                trim: MediaVideoTrim(start: 0, end: duration),
                duration: duration
            )
        }

        public var isVideo: Bool { kind == .video }
    }

    public init(items: [Item] = [], caption: String = "", selectedIndex: Int = 0) {
        self.items = items
        self.caption = caption
        self.selectedIndex = selectedIndex
    }

    public var selectedItem: Item? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    /// Returns rejected count. Never drops extras silently — the host must toast.
    public mutating func admit(_ incoming: [Item], limit: Int) -> (admitted: Int, rejected: Int) {
        var admitted = 0
        var rejected = 0
        for item in incoming {
            if items.count >= limit {
                rejected += 1
                continue
            }
            items.append(item)
            admitted += 1
        }
        if admitted > 0, items.count == admitted, selectedIndex >= items.count {
            selectedIndex = 0
        } else if admitted > 0, items.count > 0 {
            selectedIndex = min(max(selectedIndex, 0), items.count - 1)
        }
        return (admitted, rejected)
    }

    public mutating func remove(id: String) {
        items.removeAll { $0.id == id }
        if items.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = min(selectedIndex, items.count - 1)
        }
    }

    public mutating func replaceSelected(_ item: Item) {
        guard items.indices.contains(selectedIndex) else { return }
        items[selectedIndex] = item
    }

    public func title() -> String {
        Self.title(for: items)
    }

    public static func title(for items: [Item]) -> String {
        let photos = items.filter { $0.kind == .image }.count
        let videos = items.filter { $0.kind == .video }.count
        if videos == 0 {
            return photos <= 1
                ? String(localized: "Photo")
                : String(localized: "\(photos) Photos")
        }
        if photos == 0 {
            return videos <= 1
                ? String(localized: "Video")
                : String(localized: "\(videos) Videos")
        }
        return String(localized: "\(items.count) Items")
    }

    public static func overLimitMessage(limit: Int) -> String {
        String(localized: "You can send up to \(limit) photos or videos.")
    }
}
