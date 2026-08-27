# AGENTS.md

Bimbel is a **drop-in iOS conversation component**, not a messenger app. Surface 1 is the thread. Surface 2 (inbox list) is not in this package yet — do not build it except to consume `ConversationTheme`.

## Embed (~30 lines)

```swift
import Bimbel

let conversation = ConversationViewController(
    conversationID: id,
    dataSource: dataSource,
    theme: .default, // also try .blue so you do not copy mint as the only look
    header: HeaderContent(title: "Ada", subtitle: "Online", unreadBadge: 4),
    actions: ConversationActions(
        onSendText: { store.insertText($0) },           // return Message? ; nil = you already applied
        onSendAttachments: { store.insert($0) },
        onSendVoice: { store.insertVoice($0) }
    )
)
conversation.apply(store.snapshot(in: id), animatingDifferences: false)
```

## Rules

- Host calls `apply(_:animatingDifferences:)` when messages change. Do not poll arrays.
- The package **never** mints `MessageID`s. Send closures return the inserted `Message` or `nil`.
- `Participant` is not on `Message`. Look up `dataSource.participant(id:)`.
- `ImageSource` is `asset` / `url` / `data` only. No `uiImage` on the model.
- `MessageKind` has no `linkPreview` case — put previews on `.text(_, preview:)`.
- List basis is UIKit `UICollectionView` + ChatLayout. Do not replace it with SwiftUI `List`/`ScrollView`.
- Do not use InputBarAccessoryView’s bar chrome. Zustand B composer is ours.
- Do not give ChatLayout `additionalSafeAreaInsets` for the keyboard. The composer owns insets.
- Media stacks are fully rounded like the NEW bubble design, not iMessage collapse.
- Attach sheet: Plus becomes the keyboard button; composer stays floating above the sheet.

Sample app: `Sample/BimbelSample`. Tap the header title to switch Default ↔ Blue. Fake data source, no network.
