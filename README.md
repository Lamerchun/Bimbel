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

Open `Bimbel.xcworkspace` (or `Sample/BimbelSample.xcodeproj`) on macOS. iOS 17+, Xcode 16.4+ (Swift 6.1 for ChatLayout). The sample launches on the inbox; tap a row for the thread. Ada keyboard-up shot: env `BIMBEL_SHOT=ada` or args `-BIMBEL_SHOT ada`, with Simulator **Connect Hardware Keyboard** off.

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

The conversation VC owns the accessory. ChatLayout is not given `additionalSafeAreaInsets`. InputBarAccessoryView is not used.

1. Zustand B composer is plus + pill + camera + mic/send — not a full-width bar. One instance.
2. Keyboard hidden: that instance is docked in the conversation VC at the safe-area bottom (wallpaper shows through).
3. Keyboard visible: `removeFromSuperview()` first, embed the same view in the VC’s `inputAccessoryView` container, **then** `becomeFirstResponder`. Never leave it in the VC hierarchy at the same time as accessory. The VC’s `inputAccessoryView` is the container; the text view returns nil (returning its ancestor is recursive and UIKit drops the bar).
4. `collectionView.keyboardDismissMode = .interactiveWithAccessory` so drag-to-dismiss starts at the composer, not the keys.
5. List `contentInset.bottom` has one owner (`ComposerKeyboardTracker`): the top of the composer plus `layout.listComposerGap` (8). Do not add keyboard height + composer height. Do not flush layout from `scrollViewDidScroll` / `viewDidLayoutSubviews`.
6. Attach sheet is the text view’s `inputView`. Voice-lock and the attach sheet disable the dismiss pan.

Do not pin the composer to `keyboardLayoutGuide`. Do not use IBAV `KeyboardManager` as the position owner.

## Theme & materials

`ConversationTheme.default` nods at mint/teal. `ConversationTheme.blue` is the foreign accent in the sample (tap the inbox title or a conversation title). Delivery accessories are `.ticks`, `.dot`, or `.hidden` — ticks are not hard-coded.

Header glass uses Liquid Glass when `UIGlassEffect` exists at runtime (iOS 26). iOS 17/18 fall back to `.systemChromeMaterial` (neutral, no mint tint). Wallpaper is the bundled doodle tile (`wallpaper-bimbel-light` / `wallpaper-bimbel-dark`). Delivery ticks are the overlapping `delivery-double-tick` template glyph, never SF `checkmark.circle`.

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

Layout engine: [ChatLayout](https://github.com/ekazaev/ChatLayout) (MIT).
