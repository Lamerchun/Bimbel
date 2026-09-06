import UIKit

enum InboxPreviewKind: Equatable {
    case override(String)
    case draftText(String)
    case draftVoice
    case typing
    case group(sender: String, body: String)
    case body(String)
}

enum InboxPreviewResolver {
    static func kind(for item: InboxItem) -> InboxPreviewKind {
        if let override = item.previewOverride?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty
        {
            return .override(override)
        }
        if let draft = item.draftPreview {
            switch draft {
            case .text(let text):
                return .draftText(text)
            case .voice:
                return .draftVoice
            }
        }
        if item.isTyping {
            return .typing
        }
        let body = item.preview
        if let sender = item.previewSenderName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sender.isEmpty
        {
            return .group(sender: sender, body: body)
        }
        return .body(body)
    }

    static func showsOutgoingStatus(for item: InboxItem) -> Bool {
        guard item.lastOutgoingDelivery != nil else { return false }
        switch kind(for: item) {
        case .body:
            return true
        case .override, .draftText, .draftVoice, .typing, .group:
            return false
        }
    }

    static func attributedPreview(
        for item: InboxItem,
        theme: ConversationTheme
    ) -> NSAttributedString {
        let font = InboxRowMetrics.previewFont(theme: theme)
        let color = theme.colors.headerSubtitle
        let italic = italicPreviewFont(matching: font)
        switch kind(for: item) {
        case .override(let text):
            return NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color
            ])
        case .draftText(let text):
            let draft = NSMutableAttributedString(
                string: String(localized: "Draft: "),
                attributes: [
                    .font: italic,
                    .foregroundColor: theme.colors.accent
                ]
            )
            draft.append(NSAttributedString(string: text, attributes: [
                .font: italic,
                .foregroundColor: color
            ]))
            return draft
        case .draftVoice:
            let draft = NSMutableAttributedString(
                string: String(localized: "Draft"),
                attributes: [
                    .font: italic,
                    .foregroundColor: theme.colors.accent
                ]
            )
            draft.append(NSAttributedString(string: "  ", attributes: [
                .font: font,
                .foregroundColor: color
            ]))
            if let mic = UIImage(systemName: "mic.fill")?.withRenderingMode(.alwaysTemplate) {
                let attachment = NSTextAttachment()
                attachment.image = mic.withTintColor(color, renderingMode: .alwaysTemplate)
                let side = font.pointSize + 1
                attachment.bounds = CGRect(x: 0, y: font.descender + 1, width: side, height: side)
                draft.append(NSAttributedString(attachment: attachment))
            }
            return draft
        case .typing:
            return NSAttributedString(string: String(localized: "Typing…"), attributes: [
                .font: font,
                .foregroundColor: theme.colors.accent
            ])
        case .group(let sender, let body):
            let text = NSMutableAttributedString(
                string: "\(sender): ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: font.pointSize, weight: .semibold),
                    .foregroundColor: color
                ]
            )
            text.append(NSAttributedString(string: body, attributes: [
                .font: font,
                .foregroundColor: color
            ]))
            return text
        case .body(let text):
            return NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color
            ])
        }
    }

    static func accessibilityPreview(for item: InboxItem) -> String {
        switch kind(for: item) {
        case .override(let text):
            return text
        case .draftText(let text):
            return "\(String(localized: "Draft: "))\(text)"
        case .draftVoice:
            return String(localized: "Draft")
        case .typing:
            return String(localized: "Typing")
        case .group(let sender, let body):
            return "\(sender): \(body)"
        case .body(let text):
            return text
        }
    }

    private static func italicPreviewFont(matching font: UIFont) -> UIFont {
        if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return UIFont.italicSystemFont(ofSize: font.pointSize)
    }
}
