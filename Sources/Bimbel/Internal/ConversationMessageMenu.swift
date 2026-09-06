import UIKit

enum ConversationMessageMenuItem: Equatable, CaseIterable {
    case reply
    case copy
    case save
    case forward
    case delete
    case select
    case edit

    var title: String {
        switch self {
        case .reply: String(localized: "Reply")
        case .copy: String(localized: "Copy")
        case .save: String(localized: "Save")
        case .forward: String(localized: "Forward")
        case .delete: String(localized: "Delete")
        case .select: String(localized: "Select")
        case .edit: String(localized: "Edit")
        }
    }

    var systemImage: String {
        switch self {
        case .reply: "arrowshape.turn.up.left"
        case .copy: "doc.on.doc"
        case .save: "square.and.arrow.down"
        case .forward: "arrowshape.turn.up.right"
        case .delete: "trash"
        case .select: "checkmark.circle"
        case .edit: "pencil"
        }
    }

    var isDestructive: Bool { self == .delete }

    var lineImage: UIImage? {
        UIImage.bimbelComposerLine(systemImage)
    }
}

enum ConversationMessageMenu {
    static func items(for message: Message, allowsEdit: Bool) -> [ConversationMessageMenuItem] {
        var items: [ConversationMessageMenuItem] = [.reply]
        if isText(message) {
            items.append(.copy)
        }
        if isMedia(message) {
            items.append(.save)
        }
        items.append(contentsOf: [.forward, .delete, .select])
        if allowsEdit {
            items.append(.edit)
        }
        return items
    }

    static func isText(_ message: Message) -> Bool {
        if case .text = message.kind { return true }
        return false
    }

    static func isMedia(_ message: Message) -> Bool {
        switch message.kind {
        case .image, .video:
            return true
        default:
            return false
        }
    }
}
