import UIKit

/// Visual tokens shared by Surface 1 (conversation) and Surface 2 (inbox).
/// Do not introduce a parallel palette for the list.
public struct ConversationTheme: Sendable {
    public var colors: Colors
    public var materials: Materials
    public var radii: Radii
    public var layout: Layout
    public var fonts: Fonts
    public var grouping: Grouping
    public var deliveryAccessory: DeliveryAccessory

    public init(
        colors: Colors = .bimbel,
        materials: Materials = .bimbel,
        radii: Radii = .bimbel,
        layout: Layout = .bimbel,
        fonts: Fonts = .bimbel,
        grouping: Grouping = .bimbel,
        deliveryAccessory: DeliveryAccessory = .ticks
    ) {
        self.colors = colors
        self.materials = materials
        self.radii = radii
        self.layout = layout
        self.fonts = fonts
        self.grouping = grouping
        self.deliveryAccessory = deliveryAccessory
    }

    /// Default appearance. Accent nods at mint/teal chat UIs without being the only look.
    public static let `default` = ConversationTheme()

    /// Foreign accent shipped so hosts (and coding agents) do not copy the default green.
    public static let blue = ConversationTheme(
        colors: .blue,
        deliveryAccessory: .dot
    )

    public enum DeliveryAccessory: Equatable, Sendable {
        case ticks
        case dot
        case hidden
    }

    /// Holds UIKit colors, which the compiler cannot prove sendable; the tokens are only ever
    /// read, never mutated after construction.
    public struct Colors: @unchecked Sendable {
        public var wallpaper: UIColor
        public var outgoingBubble: UIColor
        public var incomingBubble: UIColor
        public var outgoingPrimaryText: UIColor
        public var incomingPrimaryText: UIColor
        public var metadata: UIColor
        public var accent: UIColor
        public var composerFill: UIColor
        public var composerStroke: UIColor
        public var composerIcon: UIColor
        public var sendFill: UIColor
        public var sendIcon: UIColor
        public var plusFill: UIColor
        public var systemChipFill: UIColor
        public var systemChipText: UIColor
        public var unreadSeparator: UIColor
        public var reactionFill: UIColor
        public var headerTitle: UIColor
        public var headerSubtitle: UIColor
        public var badgeFill: UIColor
        public var badgeText: UIColor
        public var linkTitle: UIColor
        public var fabFill: UIColor
        public var fabIcon: UIColor
        public var waveform: UIColor
        /// Inbox mute glyph. Ship 1: tertiary.
        public var inboxMute: UIColor
        /// Inbox unread pill text. Ship 1: white on accent fill.
        public var inboxUnreadText: UIColor
        /// Inbox `Draft:` prefix. Ship 1: secondary italic — not accent.
        public var inboxDraft: UIColor

        public init(
            wallpaper: UIColor,
            outgoingBubble: UIColor,
            incomingBubble: UIColor,
            outgoingPrimaryText: UIColor,
            incomingPrimaryText: UIColor,
            metadata: UIColor,
            accent: UIColor,
            composerFill: UIColor,
            composerStroke: UIColor,
            composerIcon: UIColor,
            sendFill: UIColor,
            sendIcon: UIColor,
            plusFill: UIColor,
            systemChipFill: UIColor,
            systemChipText: UIColor,
            unreadSeparator: UIColor,
            reactionFill: UIColor,
            headerTitle: UIColor,
            headerSubtitle: UIColor,
            badgeFill: UIColor,
            badgeText: UIColor,
            linkTitle: UIColor,
            fabFill: UIColor,
            fabIcon: UIColor,
            waveform: UIColor,
            inboxMute: UIColor = .tertiaryLabel,
            inboxUnreadText: UIColor = .white,
            inboxDraft: UIColor = .secondaryLabel
        ) {
            self.wallpaper = wallpaper
            self.outgoingBubble = outgoingBubble
            self.incomingBubble = incomingBubble
            self.outgoingPrimaryText = outgoingPrimaryText
            self.incomingPrimaryText = incomingPrimaryText
            self.metadata = metadata
            self.accent = accent
            self.composerFill = composerFill
            self.composerStroke = composerStroke
            self.composerIcon = composerIcon
            self.sendFill = sendFill
            self.sendIcon = sendIcon
            self.plusFill = plusFill
            self.systemChipFill = systemChipFill
            self.systemChipText = systemChipText
            self.unreadSeparator = unreadSeparator
            self.reactionFill = reactionFill
            self.headerTitle = headerTitle
            self.headerSubtitle = headerSubtitle
            self.badgeFill = badgeFill
            self.badgeText = badgeText
            self.linkTitle = linkTitle
            self.fabFill = fabFill
            self.fabIcon = fabIcon
            self.waveform = waveform
            self.inboxMute = inboxMute
            self.inboxUnreadText = inboxUnreadText
            self.inboxDraft = inboxDraft
        }

        public static let bimbel = Colors(
            wallpaper: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 11 / 255, green: 11 / 255, blue: 11 / 255, alpha: 1) // #0B0B0B
                    : UIColor(red: 240 / 255, green: 235 / 255, blue: 228 / 255, alpha: 1) // #F0EBE4
            },
            outgoingBubble: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.07, green: 0.38, blue: 0.25, alpha: 1)
                    : UIColor(red: 0.85, green: 0.97, blue: 0.82, alpha: 1)
            },
            incomingBubble: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.18, green: 0.17, blue: 0.16, alpha: 1)
                    : UIColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1)
            },
            outgoingPrimaryText: UIColor { tc in
                tc.userInterfaceStyle == .dark ? .white : UIColor(white: 0.12, alpha: 1)
            },
            incomingPrimaryText: UIColor { tc in
                tc.userInterfaceStyle == .dark ? UIColor(white: 0.95, alpha: 1) : UIColor(white: 0.12, alpha: 1)
            },
            metadata: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: 0.55)
                    : UIColor(white: 0.35, alpha: 1)
            },
            accent: UIColor(red: 0.18, green: 0.72, blue: 0.47, alpha: 1),
            composerFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.18, green: 0.19, blue: 0.20, alpha: 1)
                    : UIColor.white
            },
            composerStroke: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: 0.06)
                    : UIColor(white: 0, alpha: 0.06)
            },
            composerIcon: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 0.78, alpha: 1)
                    : UIColor(white: 0.35, alpha: 1)
            },
            sendFill: UIColor(red: 0.18, green: 0.72, blue: 0.47, alpha: 1),
            sendIcon: .white,
            plusFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.18, green: 0.19, blue: 0.20, alpha: 1)
                    : UIColor.white
            },
            systemChipFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 0.18, alpha: 0.92)
                    : UIColor(white: 1, alpha: 0.78)
            },
            systemChipText: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 0.78, alpha: 1)
                    : UIColor(white: 0.28, alpha: 1)
            },
            unreadSeparator: UIColor(red: 0.18, green: 0.72, blue: 0.47, alpha: 1),
            reactionFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 0.16, alpha: 1)
                    : UIColor.white
            },
            headerTitle: UIColor.label,
            headerSubtitle: UIColor.secondaryLabel,
            badgeFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.22, green: 0.24, blue: 0.26, alpha: 1)
                    : UIColor(white: 0.86, alpha: 1)
            },
            badgeText: UIColor.label,
            linkTitle: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.55, green: 0.95, blue: 0.72, alpha: 1)
                    : UIColor(red: 0.05, green: 0.42, blue: 0.28, alpha: 1)
            },
            fabFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.18, green: 0.19, blue: 0.20, alpha: 1)
                    : UIColor.white
            },
            fabIcon: UIColor.secondaryLabel,
            waveform: UIColor { tc in
                tc.userInterfaceStyle == .dark ? UIColor.white : UIColor(white: 0.25, alpha: 1)
            }
        )

        public static let blue = Colors(
            wallpaper: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1)
                    : UIColor(red: 0.90, green: 0.93, blue: 0.97, alpha: 1)
            },
            outgoingBubble: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.10, green: 0.32, blue: 0.62, alpha: 1)
                    : UIColor(red: 0.78, green: 0.89, blue: 1.00, alpha: 1)
            },
            incomingBubble: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1)
                    : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
            },
            outgoingPrimaryText: UIColor { tc in
                tc.userInterfaceStyle == .dark ? .white : UIColor(red: 0.07, green: 0.16, blue: 0.32, alpha: 1)
            },
            incomingPrimaryText: UIColor.label,
            metadata: UIColor.secondaryLabel,
            accent: UIColor.systemBlue,
            composerFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1)
                    : UIColor.white
            },
            composerStroke: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: 0.08)
                    : UIColor(white: 0, alpha: 0.06)
            },
            composerIcon: UIColor.secondaryLabel,
            sendFill: UIColor.systemBlue,
            sendIcon: .white,
            plusFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1)
                    : UIColor.white
            },
            systemChipFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 0.18, alpha: 0.92)
                    : UIColor(white: 1, alpha: 0.82)
            },
            systemChipText: UIColor.secondaryLabel,
            unreadSeparator: UIColor.systemBlue,
            reactionFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 0.16, alpha: 1)
                    : UIColor.white
            },
            headerTitle: UIColor.label,
            headerSubtitle: UIColor.secondaryLabel,
            badgeFill: UIColor.systemBlue,
            badgeText: .white,
            linkTitle: UIColor.systemBlue,
            fabFill: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1)
                    : UIColor.white
            },
            fabIcon: UIColor.systemBlue,
            waveform: UIColor.systemBlue
        )
    }

    public struct Materials: Sendable {
        public var headerBlurStyle: UIBlurEffect.Style
        public var usesLiquidGlassWhenAvailable: Bool

        public init(
            headerBlurStyle: UIBlurEffect.Style = .systemChromeMaterial,
            usesLiquidGlassWhenAvailable: Bool = true
        ) {
            self.headerBlurStyle = headerBlurStyle
            self.usesLiquidGlassWhenAvailable = usesLiquidGlassWhenAvailable
        }

        public static let bimbel = Materials()
    }

    public struct Radii: Equatable, Sendable {
        public var bubble: CGFloat
        public var bubbleJoin: CGFloat
        public var residualTail: CGFloat
        public var media: CGFloat
        public var composerPill: CGFloat
        public var composerControl: CGFloat
        public var chip: CGFloat
        public var sheet: CGFloat
        /// Approval rail thumbs. Ship 4 / SLICE-2-TOKENS §3.
        public var approvalThumb: CGFloat

        public init(
            bubble: CGFloat = 22,
            bubbleJoin: CGFloat = 4,
            residualTail: CGFloat = 3,
            media: CGFloat = 22,
            composerPill: CGFloat = 24,
            composerControl: CGFloat = 22,
            chip: CGFloat = 12,
            sheet: CGFloat = 28,
            approvalThumb: CGFloat = 12
        ) {
            self.bubble = bubble
            self.bubbleJoin = bubbleJoin
            self.residualTail = residualTail
            self.media = media
            self.composerPill = composerPill
            self.composerControl = composerControl
            self.chip = chip
            self.sheet = sheet
            self.approvalThumb = approvalThumb
        }

        public static let bimbel = Radii()
    }

    /// Time window for bubble clusters. Not media-stack / album spacing.
    public struct Grouping: Equatable, Sendable {
        /// Same direction (and same author in a group) cluster together inside this gap.
        public var maxGap: TimeInterval

        public init(maxGap: TimeInterval = 180) {
            self.maxGap = maxGap
        }

        public static let bimbel = Grouping()
    }

    public struct Layout: Equatable, Sendable {
        public var bubbleMaxWidthRatio: CGFloat
        public var sequenceGap: CGFloat
        public var clusterGap: CGFloat
        public var mediaStackGap: CGFloat
        public var incomingAvatarSize: CGFloat
        public var headerHeightCompact: CGFloat
        public var headerHeightTall: CGFloat
        public var headerAvatarSize: CGFloat
        public var hitTarget: CGFloat
        public var composerControlSize: CGFloat
        /// Distance from the lowest pixel of the last cell (tail, time, reaction)
        /// to the top edge of the composer. Not to the keyboard keys. Residual
        /// tail lives inside the cell — do not add it on top of this gap.
        public var listComposerGap: CGFloat
        public var composerGap: CGFloat
        public var replySwipeThreshold: CGFloat
        public var listHorizontalInset: CGFloat
        /// Ship 1 inbox row. Same token family as the thread — not a second system.
        public var inboxAvatar: CGFloat
        public var inboxRowMinHeight: CGFloat
        public var inboxHInset: CGFloat
        public var inboxAvatarGap: CGFloat
        public var inboxTitlePreviewGap: CGFloat
        public var inboxTrailingGap: CGFloat
        public var inboxMute: CGFloat
        public var inboxUnreadPillHeight: CGFloat
        public var inboxUnreadDot: CGFloat
        /// Hairline under the text column, not under the avatar.
        public var inboxSeparatorInset: CGFloat
        /// Hard cap for one Approval send. Over-limit shows a toast — never silent truncate. §3: 10.
        public var maxAttachmentsPerSend: Int
        /// Approval rail thumb size. §3: 64.
        public var approvalThumb: CGFloat
        /// Gap between approval rail thumbs. §3: 8.
        public var approvalThumbGap: CGFloat
        /// Header / approval close glyph. Same 22 ultraLight family as the composer.
        public var headerIcon: CGFloat
        /// Draw-editor stroke width. §3: ~4, one color = accent.
        public var drawStrokeWidth: CGFloat
        /// Hold-mic: slide left this far to cancel.
        public var voiceCancelTranslation: CGFloat
        /// Hold-mic: slide up this far to lock.
        public var voiceLockTranslation: CGFloat
        /// Tight spacing inside a time cluster. Same value as `clusterGap`. Not `grouping.maxGap`.
        public var groupingInnerSpacing: CGFloat {
            get { clusterGap }
            set { clusterGap = newValue }
        }
        /// Spacing between clusters / sequences. Same value as `sequenceGap`. Not media-stack gap.
        public var groupingSequenceSpacing: CGFloat {
            get { sequenceGap }
            set { sequenceGap = newValue }
        }

        public init(
            bubbleMaxWidthRatio: CGFloat = 0.78,
            sequenceGap: CGFloat = 10,
            clusterGap: CGFloat = 3,
            mediaStackGap: CGFloat = 2,
            incomingAvatarSize: CGFloat = 28,
            headerHeightCompact: CGFloat = 44,
            headerHeightTall: CGFloat = 56,
            headerAvatarSize: CGFloat = 32,
            hitTarget: CGFloat = 44,
            composerControlSize: CGFloat = 44,
            composerGap: CGFloat = 8,
            listComposerGap: CGFloat = 8,
            replySwipeThreshold: CGFloat = 56,
            listHorizontalInset: CGFloat = 10,
            inboxAvatar: CGFloat = 56,
            inboxRowMinHeight: CGFloat = 76,
            inboxHInset: CGFloat = 16,
            inboxAvatarGap: CGFloat = 12,
            inboxTitlePreviewGap: CGFloat = 2,
            inboxTrailingGap: CGFloat = 8,
            inboxMute: CGFloat = 16,
            inboxUnreadPillHeight: CGFloat = 20,
            inboxUnreadDot: CGFloat = 10,
            inboxSeparatorInset: CGFloat = 68,
            maxAttachmentsPerSend: Int = 10,
            approvalThumb: CGFloat = 64,
            approvalThumbGap: CGFloat = 8,
            headerIcon: CGFloat = 22,
            drawStrokeWidth: CGFloat = 4,
            voiceCancelTranslation: CGFloat = 80,
            voiceLockTranslation: CGFloat = 80
        ) {
            self.bubbleMaxWidthRatio = bubbleMaxWidthRatio
            self.sequenceGap = sequenceGap
            self.clusterGap = clusterGap
            self.mediaStackGap = mediaStackGap
            self.incomingAvatarSize = incomingAvatarSize
            self.headerHeightCompact = headerHeightCompact
            self.headerHeightTall = headerHeightTall
            self.headerAvatarSize = headerAvatarSize
            self.hitTarget = hitTarget
            self.composerControlSize = composerControlSize
            self.listComposerGap = listComposerGap
            self.composerGap = composerGap
            self.replySwipeThreshold = replySwipeThreshold
            self.listHorizontalInset = listHorizontalInset
            self.inboxAvatar = inboxAvatar
            self.inboxRowMinHeight = inboxRowMinHeight
            self.inboxHInset = inboxHInset
            self.inboxAvatarGap = inboxAvatarGap
            self.inboxTitlePreviewGap = inboxTitlePreviewGap
            self.inboxTrailingGap = inboxTrailingGap
            self.inboxMute = inboxMute
            self.inboxUnreadPillHeight = inboxUnreadPillHeight
            self.inboxUnreadDot = inboxUnreadDot
            self.inboxSeparatorInset = inboxSeparatorInset
            self.maxAttachmentsPerSend = maxAttachmentsPerSend
            self.approvalThumb = approvalThumb
            self.approvalThumbGap = approvalThumbGap
            self.headerIcon = headerIcon
            self.drawStrokeWidth = drawStrokeWidth
            self.voiceCancelTranslation = voiceCancelTranslation
            self.voiceLockTranslation = voiceLockTranslation
        }

        public static let bimbel = Layout()
    }

    /// Same reasoning as `Colors`: UIFont is immutable in practice once a token is built.
    public struct Fonts: @unchecked Sendable {
        public var body: UIFont
        public var metadata: UIFont
        public var headerTitle: UIFont
        public var headerSubtitle: UIFont
        public var chip: UIFont
        public var linkTitle: UIFont
        public var linkSummary: UIFont
        /// Inbox title. Ship 1: headline / semibold.
        public var inboxTitle: UIFont
        /// Inbox time. Ship 1: caption1.
        public var inboxTime: UIFont
        /// Inbox preview and `Draft:`. Ship 1: subheadline (italic for draft).
        public var inboxPreview: UIFont
        /// Inbox unread pill. Ship 1: caption2 bold.
        public var inboxUnread: UIFont
        /// Approval text overlay. Same size as bubble body.
        public var bubbleBody: UIFont

        public init(
            body: UIFont = .systemFont(ofSize: 16, weight: .regular),
            metadata: UIFont = .systemFont(ofSize: 11, weight: .regular),
            headerTitle: UIFont = .systemFont(ofSize: 17, weight: .semibold),
            headerSubtitle: UIFont = .systemFont(ofSize: 12, weight: .regular),
            chip: UIFont = .systemFont(ofSize: 12, weight: .medium),
            linkTitle: UIFont = .systemFont(ofSize: 15, weight: .semibold),
            linkSummary: UIFont = .systemFont(ofSize: 13, weight: .regular),
            inboxTitle: UIFont = Self.ship1InboxTitle,
            inboxTime: UIFont = .preferredFont(forTextStyle: .caption1),
            inboxPreview: UIFont = .preferredFont(forTextStyle: .subheadline),
            inboxUnread: UIFont = Self.ship1InboxUnread,
            bubbleBody: UIFont = .systemFont(ofSize: 16, weight: .regular)
        ) {
            self.body = body
            self.metadata = metadata
            self.headerTitle = headerTitle
            self.headerSubtitle = headerSubtitle
            self.chip = chip
            self.linkTitle = linkTitle
            self.linkSummary = linkSummary
            self.inboxTitle = inboxTitle
            self.inboxTime = inboxTime
            self.inboxPreview = inboxPreview
            self.inboxUnread = inboxUnread
            self.bubbleBody = bubbleBody
        }

        /// Ship 1 inbox title: headline size, semibold. Public so default arguments
        /// on this `public` init stay visible to hosts and Swift 6.1 clients.
        public static var ship1InboxTitle: UIFont {
            let size = UIFont.preferredFont(forTextStyle: .headline).pointSize
            return .systemFont(ofSize: size, weight: .semibold)
        }

        /// Ship 1 unread pill: caption2 size, bold.
        public static var ship1InboxUnread: UIFont {
            let size = UIFont.preferredFont(forTextStyle: .caption2).pointSize
            return .systemFont(ofSize: size, weight: .bold)
        }

        public static let bimbel = Fonts()
    }
}
