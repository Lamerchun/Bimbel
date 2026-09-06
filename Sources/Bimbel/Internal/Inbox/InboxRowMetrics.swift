import UIKit

enum InboxRowMetrics {
    static let previewLines = 2

    static func previewFont(theme: ConversationTheme) -> UIFont {
        theme.fonts.inboxPreview
    }

    static func draftFont(theme: ConversationTheme) -> UIFont {
        italic(matching: theme.fonts.inboxPreview)
    }

    static func previewHeight(theme: ConversationTheme) -> CGFloat {
        previewHeight(font: theme.fonts.inboxPreview)
    }

    static func previewHeight(font: UIFont) -> CGFloat {
        ceil(font.lineHeight) * CGFloat(previewLines)
    }

    static func estimatedRowHeight(theme: ConversationTheme) -> CGFloat {
        let title = ceil(theme.fonts.inboxTitle.lineHeight)
        let stacked = verticalPadding(theme: theme)
            + title
            + theme.layout.inboxTitlePreviewGap
            + previewHeight(theme: theme)
            + verticalPadding(theme: theme)
        return max(theme.layout.inboxRowMinHeight, stacked)
    }

    static func verticalPadding(theme: ConversationTheme) -> CGFloat {
        max(0, (theme.layout.inboxRowMinHeight - theme.layout.inboxAvatar) / 2)
    }

    static func italic(matching font: UIFont) -> UIFont {
        if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return UIFont.italicSystemFont(ofSize: font.pointSize)
    }

    static func muteSymbol(size: CGFloat) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .ultraLight)
        return UIImage(systemName: "speaker.slash", withConfiguration: config)
    }
}

enum InboxSwipeChrome {
    static let pinFill = UIColor.systemGray
    static let muteFill = UIColor.systemGray
    static let deleteFill = UIColor.systemRed

    static func readFill(theme: ConversationTheme) -> UIColor {
        theme.colors.accent
    }

    static func symbol(_ name: String) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .ultraLight)
        return UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
    }
}
