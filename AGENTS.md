# AGENTS.md

Bimbel is a **drop-in iOS conversation component**, not a messenger app. Two surfaces, one `ConversationTheme`:

1. Inbox list (`InboxView` / `InboxViewController`)
2. Conversation thread (`ConversationView` / `ConversationViewController`)

No Calls tab, Status, Settings, or Communities.

## Embed

```swift
import Bimbel

let inbox = InboxViewController(
    dataSource: store,
    theme: .default, // also try .blue so you do not copy mint as the only look
    actions: InboxActions(onOpen: { id in
        let thread = ConversationViewController(
            conversationID: id,
            dataSource: store,
            theme: .default,
            header: HeaderContent(title: "Ada"),
            actions: ConversationActions(
                onBack: { nav.popViewController(animated: true) },
                onSendText: { store.insertText($0, in: id) }
            )
        )
        thread.apply(store.snapshot(in: id), animatingDifferences: false)
        nav.pushViewController(thread, animated: true)
    })
)
inbox.apply(store.snapshot(), animatingDifferences: false)
```

## Rules

- Host calls `apply(_:animatingDifferences:)` when inbox rows **or** messages change. Do not poll arrays.
- The package **never** mints `ConversationID`s or `MessageID`s.
- Send closures return the inserted `Message` or `nil`.
- `Participant` is not on `Message`. Look up `dataSource.participant(id:)`.
- `ImageSource` is `asset` / `url` / `data` only. No `uiImage` on the model.
- `MessageKind` has no `linkPreview` case — put previews on `.text(_, preview:)`.
- Thread list basis is UIKit `UICollectionView` + ChatLayout. Do not replace it with SwiftUI `List`/`ScrollView`.
- Inbox is a `UITableView` (swipe pin/mute/delete). Same theme tokens. No second look.
- Do not use InputBarAccessoryView. Zustand B composer is ours.
- Keyboard: Signal-iOS `ConversationBottomBar` — composer stays in the VC, `bottomAnchor = keyboardLayoutGuide.topAnchor` when `shouldAttachToKeyboardLayoutGuide` is true. No `inputAccessoryView`. `keyboardDismissMode = .interactive`. Tap Message focuses immediately (`textViewShouldBeginEditing` returns true).
- Do not give ChatLayout `additionalSafeAreaInsets` for the keyboard. One inset owner (`ComposerKeyboardTracker`): covering edge is composer top + `listComposerGap` (8). Do not add keyboard height on top of the layout-guide pin. Do not flush layout from `scrollViewDidScroll` / `viewDidLayoutSubviews`. `detach()` on the main actor; do not touch observers in `deinit`.
- Attach sheet: Plus becomes the keyboard button; composer stays in the VC above the sheet. Voice-lock and the sheet disable the dismiss pan.
- Media stacks are fully rounded like the NEW bubble design, not iMessage collapse.

Sample app: `Sample/BimbelSample`. Launches on the inbox. Tap **Ada** for the full thread. Tap the large title (or a conversation title) to switch Default ↔ Blue.
