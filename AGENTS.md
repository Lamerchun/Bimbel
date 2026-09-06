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
- Send closures return the inserted `Message` or `nil`. `onSendMedia` returns `[Message]?`.
- Camera, PHPicker, and attach-sheet recents go through `EditSession` (Approval → Crop / Draw / Text) before `onSendMedia`. Do not send a raw `UIImage`. Over `layout.maxAttachmentsPerSend` (10) toasts — no silent truncate.
- Tap image/video in a bubble opens the fullscreen pager (pinch-zoom, interactive dismiss). Long-press stays a targeted bubble preview — do not add `willPerformPreviewActionForMenuWith`. No “All media” grid.
- `Participant` is not on `Message`. Look up `dataSource.participant(id:)`.
- `ImageSource` is `asset` / `url` / `data` only. No `uiImage` on the model.
- `MessageKind` has no `linkPreview` case — put previews on `.text(_, preview:)`.
- Thread list basis is UIKit `UICollectionView` + ChatLayout. Do not replace it with SwiftUI `List`/`ScrollView`.
- Inbox is a `UITableView` (leading read/pin, trailing mute/delete). Same theme tokens. No second look.
- Do not use InputBarAccessoryView. Zustand B composer is ours.
- Keyboard: Signal-iOS `ConversationBottomBar` — composer stays in the VC, `bottomAnchor = keyboardLayoutGuide.topAnchor` when `shouldAttachToKeyboardLayoutGuide` is true. No `inputAccessoryView`. `keyboardDismissMode = .interactive` on the list. Vertical pans that start on Plus / pill chrome / camera forward to `collectionView.panGestureRecognizer`. The Message field caret/selection does not steal dismiss. Finger-up without a committed dismiss snaps keyboard + composer back together. Tap Message focuses immediately (`textViewShouldBeginEditing` returns true).
- Do not give ChatLayout `additionalSafeAreaInsets` for the keyboard. One inset owner (`ComposerKeyboardTracker`): covering edge is composer top + `listComposerGap` (8). Do not add keyboard height on top of the layout-guide pin. Do not flush layout from `scrollViewDidScroll` / `viewDidLayoutSubviews`. `detach()` on the main actor; do not touch observers in `deinit`.
- Attach sheet: Plus becomes the keyboard button; composer stays in the VC above the sheet. Voice hold/lock and the sheet disable the dismiss pan.
- Voice: hold mic (empty composer) → haptic → recording bar (waveform + duration + slide-to-cancel). Slide left past threshold cancels; release under threshold sends; slide up locks. Locked buttons: Pause · Preview · Send · Discard (VoiceOver actions). Voice bubble: waveform · duration · play/pause · 1×/1.5×/2×. `onSendVoice(URL, duration, waveform, quote?)`. Everyday copy only.
- Media stacks are fully rounded like the NEW bubble design, not iMessage collapse.

Sample app: `Sample/BimbelSample`. Launches on the inbox. Tap **Ada** for the full thread. Tap the large title (or a conversation title) to switch Default ↔ Blue.
