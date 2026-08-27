import UIKit

/// Visual tokens shared by Surface 1 (conversation) and Surface 2 (inbox).
/// Do not introduce a parallel palette for the list.
public struct ConversationTheme: Sendable {
    public var colors: Colors
    public var materials: Materials
    public var radii: Radii
    public var layout: Layout
    public var fonts: Fonts
    public var deliveryAccessory: DeliveryAccessory

    public init(
        colors: Colors = .bimbel,
        materials: Materials = .bimbel,
        radii: Radii = .bimbel,
        layout: Layout = .bimbel,
        fonts: Fonts = .bimbel,
        deliveryAccessory: DeliveryAccessory = .ticks
    ) {
        self.colors = colors
        self.materials = materials
        self.radii = radii
        self.layout = layout
        self.fonts = fonts
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
            waveform: UIColor
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
        }

        public static let bimbel = Colors(
            wallpaper: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.07, green: 0.08, blue: 0.08, alpha: 1)
                    : UIColor(red: 0.93, green: 0.91, blue: 0.88, alpha: 1)
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
            headerBlurStyle: UIBlurEffect.Style = .systemUltraThinMaterial,
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

        public init(
            bubble: CGFloat = 22,
            bubbleJoin: CGFloat = 4,
            residualTail: CGFloat = 10,
            media: CGFloat = 22,
            composerPill: CGFloat = 24,
            composerControl: CGFloat = 22,
            chip: CGFloat = 12,
            sheet: CGFloat = 28
        ) {
            self.bubble = bubble
            self.bubbleJoin = bubbleJoin
            self.residualTail = residualTail
            self.media = media
            self.composerPill = composerPill
            self.composerControl = composerControl
            self.chip = chip
            self.sheet = sheet
        }

        public static let bimbel = Radii()
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
        public var composerGap: CGFloat
        public var replySwipeThreshold: CGFloat
        public var listHorizontalInset: CGFloat

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
            replySwipeThreshold: CGFloat = 56,
            listHorizontalInset: CGFloat = 10
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
            self.composerGap = composerGap
            self.replySwipeThreshold = replySwipeThreshold
            self.listHorizontalInset = listHorizontalInset
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

        public init(
            body: UIFont = .systemFont(ofSize: 16, weight: .regular),
            metadata: UIFont = .systemFont(ofSize: 11, weight: .regular),
            headerTitle: UIFont = .systemFont(ofSize: 17, weight: .semibold),
            headerSubtitle: UIFont = .systemFont(ofSize: 12, weight: .regular),
            chip: UIFont = .systemFont(ofSize: 12, weight: .medium),
            linkTitle: UIFont = .systemFont(ofSize: 15, weight: .semibold),
            linkSummary: UIFont = .systemFont(ofSize: 13, weight: .regular)
        ) {
            self.body = body
            self.metadata = metadata
            self.headerTitle = headerTitle
            self.headerSubtitle = headerSubtitle
            self.chip = chip
            self.linkTitle = linkTitle
            self.linkSummary = linkSummary
        }

        public static let bimbel = Fonts()
    }
}
