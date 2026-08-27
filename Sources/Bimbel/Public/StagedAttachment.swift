import Foundation

public struct StagedAttachment: Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: Kind

    public enum Kind: Hashable, Sendable {
        case image(ImageSource)
        case video(ImageSource)
        case document(Document)
        case location(latitude: Double, longitude: Double, label: String?)
        case contact(displayName: String)
    }

    public init(id: String = UUID().uuidString, kind: Kind) {
        self.id = id
        self.kind = kind
    }
}

public enum AttachmentAction: String, Hashable, Sendable {
    case photos
    case camera
    case location
    case contact
    case document
    case poll
    case event
    case aiImages
}
