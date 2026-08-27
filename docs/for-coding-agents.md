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

- `InboxItem`: `id` (`ConversationID`), `title`, `preview`, `timestamp`, `avatar`, `unreadCount`, `isPinned`, `isMuted`, `isTyping`, `isGroup`.
- `InboxActions.onOpen(ConversationID)` from the row. Pin / mute / delete are host persistence; then `apply` again.
- Package never mints conversation IDs.

### Thread

- `ConversationDataSource.snapshot(in:)`, `loadOlder(in:) async throws`, `participant(id:)`.
- `Message`: `id`, `senderID`, `sentAt`, `kind`, `replyTo`, `reactions`, `delivery`, `isEdited`, `isOutgoing`.
- `MessageKind`: `text(String, preview:)`, `image`, `video`, `voice`, `document`, `system`. No separate link-preview kind.
- `onSendText` / `onSendAttachments` / `onSendVoice` return `Message?` (non-nil → package inserts; nil → host already applied).

## Keyboard (do not “binary hide”)

See README → Keyboard. One composer view. When the keyboard will show: `removeFromSuperview()` first, embed in the VC’s `inputAccessoryView` container, **then** `becomeFirstResponder`. Never two hierarchies. The VC owns the accessory (`canBecomeFirstResponder == true`); the text view must not return its ancestor. `keyboardDismissMode = .interactiveWithAccessory`. List insets have one owner (`ComposerKeyboardTracker`): covering edge = composer top + `listComposerGap` (8). Do not add keyboard height + composer height. Do not flush layout from `scrollViewDidScroll` / `viewDidLayoutSubviews`. Do not use IBAV `KeyboardManager`.

## Themes

Ship at least two looks in any demo: `ConversationTheme.default` and `ConversationTheme.blue`. Inbox and thread share the tokens.

Header glass: Liquid Glass on iOS 26 (`UIGlassEffect` if present), otherwise `.systemChromeMaterial` (neutral, no mint tint).

## Sample

Open `Bimbel.xcworkspace`. Target `BimbelSample`. Starts on the inbox. Tap Ada for the mixed-kind thread. Tap the title to switch Default ↔ Blue.

Lock 5 keyboard-up shot: `BIMBEL_SHOT=ada` (env) or `-BIMBEL_SHOT ada` (args). Simulator → I/O → Keyboard → Connect Hardware Keyboard **off**. Sample opens Ada, reparents the composer, then focuses the text view so software QWERTZ stands.
