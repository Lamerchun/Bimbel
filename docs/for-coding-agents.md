# For coding agents

Bimbel is a reusable native iOS conversation **component**. Product name is Bimbel. It is not a full chat app (no login, calls, status, or settings).

## Public API

Two surfaces, same `ConversationTheme`:

```swift
InboxViewController(
    dataSource: InboxDataSource,
    theme: ConversationTheme.default,
    actions: InboxActions()
)
inbox.apply(snapshot, animatingDifferences: true)

ConversationView(
    conversationID: ConversationID,
    dataSource: ConversationDataSource,
    theme: ConversationTheme.default,
    header: HeaderContent(...),
    actions: ConversationActions()
)
conversation.apply(snapshot, animatingDifferences: true)
```

### Inbox

- `InboxItem`: `id` (`ConversationID`), `title`, `preview`, `timestamp`, `avatar`, `unreadCount` **or** `markedUnread`, `isMuted`, `isPinned`, `draftPreview?`, `previewSenderName?`, `lastOutgoingDelivery?`, `previewOverride?`, `participantNames`, `isTyping`, `isGroup`.
- Preview priority: host override → draft (`Draft:` / voice draft + mic) → typing → group `Sender:` + body → 1:1 body (attachment labels such as Photo, Video, Voice).
- Row tokens (Ship 1, `ConversationTheme.layout` / fonts / colors — same family): `inboxAvatar` 56, `inboxRowMinHeight` 76, `inboxHInset` 16, `inboxAvatarGap` 12, `inboxTitlePreviewGap` 2, `inboxTrailingGap` 8, `inboxMute` 16, `inboxUnreadPillHeight` 20 capsule, `inboxUnreadDot` 10, `inboxSeparatorInset` 68 (hairline under text). Title headline/semibold; time caption1; preview subheadline 2 lines; `Draft:` subheadline italic; unread caption2 bold white on accent (`>99` → `99+`). Mute tertiary `speaker.slash` ultraLight 16. Outgoing ticks only when the preview is the host’s last message. Search hides unread + status.
- Swipe: leading Read/Unread = accent, Pin = system gray; trailing Mute = system gray, Delete = systemRed last. SF ultraLight white on fills.
- `InboxActions`: `onOpen`, `onToggleRead`, `onTogglePin`, `onToggleMute`, `onDelete`. Archive on the long-press menu only when `supportsArchive` / `onArchive` is set. Host persists, then `apply` again.
- Search V1 is `UISearchController` (title + participant names only). Optional `Pinned` section from `isPinned`.
- Package never mints conversation IDs.

### Thread

- `ConversationDataSource.snapshot(in:)`, `loadOlder(in:) async throws`, `participant(id:)`.
- `Message`: `id`, `senderID`, `sentAt`, `kind`, `replyTo`, `reactions`, `delivery`, `isEdited`, `isOutgoing`.
- `MessageKind`: `text(String, preview:)`, `image`, `video`, `voice`, `document`, `system`. No separate link-preview kind.
- `onSendText` / `onSendAttachments` / `onSendVoice` return `Message?` (non-nil → package inserts; nil → host already applied).

## Keyboard (do not “binary hide”)

See README → Keyboard. Signal-iOS `ConversationBottomBar`: composer stays in the conversation VC; pin `bottomAnchor` to `keyboardLayoutGuide.topAnchor` when `shouldAttachToKeyboardLayoutGuide` is true. No `inputAccessoryView`. `textViewShouldBeginEditing` returns true. `keyboardDismissMode = .interactive`. List insets have one owner (`ComposerKeyboardTracker`): covering edge = composer top + `listComposerGap` (8). Do not add keyboard height on top of the layout-guide pin. Do not flush layout from `scrollViewDidScroll` / `viewDidLayoutSubviews`. Do not use IBAV `KeyboardManager`. SwiftUI `ConversationView` wraps `ConversationViewController` — do not rebuild the thread in SwiftUI.

## Themes

Ship at least two looks in any demo: `ConversationTheme.default` and `ConversationTheme.blue`. Inbox and thread share the tokens.

Header glass: Liquid Glass on iOS 26 (`UIGlassEffect` if present), otherwise `.systemChromeMaterial` (neutral, no mint tint).

## Sample

Open `Bimbel.xcworkspace`. Target `BimbelSample`. Starts on the inbox. Tap Ada for the mixed-kind thread. Tap the title to switch Default ↔ Blue.

Lock 5 keyboard-up shot: `BIMBEL_SHOT=ada` (env) or `-BIMBEL_SHOT ada` (args). Simulator → I/O → Keyboard → Connect Hardware Keyboard **off**. Sample opens Ada and focuses the layout-guide-pinned text view so software QWERTZ stands.
