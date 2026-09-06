import UIKit

enum InboxRowMetrics {
    static let avatarSize: CGFloat = 56
    static let horizontalInset: CGFloat = 14
    static let avatarTextGap: CGFloat = 12
    static let previewLines = 2
    static let unreadDotSize: CGFloat = 10
    static let verticalPadding: CGFloat = 12

    static var separatorInset: CGFloat {
        horizontalInset + avatarSize + avatarTextGap
    }

    static func previewFont(theme _: ConversationTheme) -> UIFont {
        .systemFont(ofSize: 15, weight: .regular)
    }

    static func previewHeight(theme: ConversationTheme) -> CGFloat {
        previewHeight(font: previewFont(theme: theme))
    }

    static func previewHeight(font: UIFont) -> CGFloat {
        ceil(font.lineHeight) * CGFloat(previewLines)
    }

    static func estimatedRowHeight(theme: ConversationTheme) -> CGFloat {
        let title = ceil(UIFont.systemFont(ofSize: 16, weight: .regular).lineHeight)
        return verticalPadding + title + 4 + previewHeight(theme: theme) + verticalPadding
    }
}
