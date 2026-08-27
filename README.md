# Bimbel

Native iOS chat component (conversation list + conversation). Sample app included. Drop-in for apps and coding agents.

Bimbel is a native iOS chat component for the conversation list and the conversation itself. Not a full chat app. The sample app is there to embed, test, and so coding agents can drop it in. Default theme is Bimbel. Sample accent is Blue.

## Stand der Dinge

Projektstart: 27. August 2026. Surface 1 (Conversation) und Surface 2 (Inbox / Unterhaltungsübersicht) liegen als Swift Package + Sample-App im Repo.

Erster Schnitt: Conversation-View (Zustand B: Liquid Glass, floating Composer), Keyboard inkl. Drag-to-dismiss, Voice-Lock. Inbox-Liste mit denselben Tokens.

| Bereich | Wer | Stand |
| --- | --- | --- |
| Research & Requirements | Quang | Spec für die Chat-Komponente |
| UI / UX | Thang | Tokens, Surfaces, Locks für die Umsetzung |
| iOS / Swift | Tuan | Native Komponente + Sample-App |
| Texte nach außen | Laura | Package-Copy, Captions, einheitlicher Ton |
| Marketing | Miriam | Repo, Status, Screenshots, Mitmachen |

Nächster sichtbarer Schritt: Simulator-Screenshots.

Open `Bimbel.xcworkspace` (or `Sample/BimbelSample.xcodeproj`) on macOS. iOS 17+, Xcode 16.4+ (Swift 6.1 for ChatLayout). The sample launches on the inbox; tap a row for the thread.

## Embed

```swift
import Bimbel

let inbox = InboxViewController(
    dataSource: store,
    theme: .default,            // or .blue / your tokens
    actions: InboxActions(
        onOpen: { id in showThread(id) },
        onPin: { id in store.togglePin(id); inbox.apply(store.snapshot(), animatingDifferences: true) },
        onMute: { id in store.toggleMute(id); inbox.apply(store.snapshot(), animatingDifferences: true) },
        onDelete: { id in store.delete(id); inbox.apply(store.snapshot(), animatingDifferences: true) }
    )
)
navigation.setViewControllers([inbox], animated: false)

func showThread(_ id: ConversationID) {
    let conversation = ConversationViewController(
        conversationID: id,
        dataSource: store,
        theme: .default,
        header: HeaderContent(title: "Ada"),
        actions: ConversationActions(
            onBack: { navigation.popViewController(animated: true) },
            onSendText: { store.insertText($0, in: id) }
        )
    )
    conversation.apply(store.snapshot(in: id), animatingDifferences: false)
    navigation.pushViewController(conversation, animated: true)
}
```

Host owns data. Call `apply` on **both** surfaces when their snapshots change. Send closures return `Message?`. The package never mints IDs.

SwiftUI: `InboxView(...)` and `ConversationView(...)` wrap the same controllers. Keep the UIKit controllers when you need `apply`.

Coding-agent notes: [AGENTS.md](AGENTS.md) · [docs/for-coding-agents.md](docs/for-coding-agents.md)

## Keyboard

The composer owns keyboard insets. ChatLayout is not given `additionalSafeAreaInsets`.

1. Zustand B composer is a subview (plus + pill + camera + mic/send), not InputBarAccessoryView chrome.
2. IBAV `KeyboardManager` pins that subview to the keyboard and tracks interactive-dismiss pans (`bind(to: collectionView)` + `keyboardDismissMode = .interactive`).
3. Collection `contentInset.bottom` is derived from the composer frame so the last bubble stays above the pill.
4. A zero-height dummy `inputAccessoryView` on the text view keeps the UIKit keyboard session without drawing a bar.
5. The attach sheet is the text view’s `inputView`, so the same tracker keeps the composer floating above the sheet. Plus becomes the keyboard button while the sheet is up.

`keyboardLayoutGuide` was considered; KeyboardManager already follows the finger for interactive dismiss.

## Theme & materials

`ConversationTheme.default` nods at mint/teal. `ConversationTheme.blue` is the foreign accent in the sample (tap the inbox title or a conversation title). Delivery accessories are `.ticks`, `.dot`, or `.hidden` — ticks are not hard-coded.

Header glass uses Liquid Glass when `UIGlassEffect` exists at runtime (iOS 26). iOS 17/18 fall back to `.systemUltraThinMaterial`. Wallpaper is a solid/quiet color; the package ships no doodle asset.

## Sponsors

[![Sponsor](https://img.shields.io/github/sponsors/Lamerchun?label=Sponsor)](https://github.com/sponsors/Lamerchun)

Logo-Sponsoren, sobald es welche gibt.

## Screenshots

Noch keine. Mocks und Simulator-Aufnahmen: `docs/screenshots/`

Captions nur zur Komponente, Name Bimbel, keine fremden Marken.

## Mitmachen

Issues und PRs willkommen, solange sie an der Komponente bleiben (Liste + Conversation, nicht Status/Calls/Settings).

- Composer und Keyboard (Drag-to-dismiss)
- Bubbles, Reply, Reaktionen
- Accessibility, Dark Mode, Liquid Glass
- Agent-freundliche API und Docs

Siehe [CONTRIBUTING.md](CONTRIBUTING.md).

Layout engine: [ChatLayout](https://github.com/ekazaev/ChatLayout) (MIT). Keyboard helper: [InputBarAccessoryView](https://github.com/nathantannar4/InputBarAccessoryView) `KeyboardManager` only (MIT).
