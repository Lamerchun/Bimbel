# For coding agents

Bimbel is a reusable native iOS conversation **component**. Product name is Bimbel. It is not a full chat app (no login, calls, status, or settings).

## Public API

```swift
public typealias MessageID = String
public typealias UserID = String
public typealias ConversationID = String

ConversationView(
    conversationID: ConversationID,
    dataSource: ConversationDataSource,
    theme: ConversationTheme.default,
    header: HeaderContent(...),
    actions: ConversationActions()  // all closures optional
)
```

UIKit host: `ConversationViewController`. Same initializer. Call `apply(_ snapshot:animatingDifferences:)` when the thread changes.

### Data

- `ConversationDataSource.snapshot(in:)`, `loadOlder(in:) async throws`, `participant(id:)`.
- `Message`: `id`, `senderID`, `sentAt`, `kind`, `replyTo`, `reactions`, `delivery`, `isEdited`, `isOutgoing`.
- `MessageKind`: `text(String, preview:)`, `image`, `video`, `voice`, `document`, `system`. No separate link-preview kind.
- `DeliveryState`: `sending`, `sent`, `delivered`, `read`, `failed`.
- `ConversationTheme.deliveryAccessory`: `.ticks` | `.dot` | `.hidden`.

### Send

`onSendText` / `onSendAttachments` / `onSendVoice` return `Message?`.

- Non-nil → package inserts via `apply`.
- Nil → host already pushed a snapshot.
- Package never mints IDs.

## Keyboard (do not “binary hide”)

See README → Keyboard. Owner is the composer + IBAV `KeyboardManager`. Interactive dismiss on the collection view must drag the keyboard **and** the composer together.

## Themes

Ship at least two looks in any demo: `ConversationTheme.default` and `ConversationTheme.blue` (or another foreign accent). Do not treat mint/teal as the only appearance.

Header glass: Liquid Glass on iOS 26 (`UIGlassEffect` if present), otherwise `.systemUltraThinMaterial`.

## Sample

Open `Bimbel.xcworkspace`. Target `BimbelSample`. Fake `ConversationDataSource`, mixed kinds, send, typing (Back in the sample), hold-to-record (state machine + AVAudioRecorder when the session allows).
