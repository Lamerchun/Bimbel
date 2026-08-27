# Bimbel

The native iOS chat component people have been waiting for. Conversation list + thread, Swift.

Bimbel ist keine Chat-App. Es ist die native iOS-Komponente für die Übersicht der Unterhaltungen und den Chat selbst: smooth, native, sexy. Eine minimale Sample-App im Repo bindet sie ein, für Tests und damit man etwas sieht.

Drop-in für Coding-Agenten: Swift Package, `ConversationView` plus `apply(snapshot)`, Beispielcode. Default-Theme heißt Bimbel. Die Sample-App nutzt den Accent Blue, damit niemand das Theme einfach durchreicht.

## Stand der Dinge

Projektstart: 27. August 2026. Noch kein Package-Code im Repo.

Erster Schnitt: Conversation-View (Zustand B: Liquid Glass, floating Composer), Keyboard inkl. Drag-to-dismiss, Voice-Lock. Liste folgt als Surface 2, gleiche Tokens.

| Bereich | Wer | Stand |
| --- | --- | --- |
| Research & Requirements | Quang | Spec für die Chat-Komponente |
| UI / UX | Thang | Tokens, Surfaces, Locks für die Umsetzung |
| iOS / Swift | Tuan | Native Komponente + Sample-App |
| Texte nach außen | Laura | Package-Copy, Captions, einheitlicher Ton |
| Marketing | Miriam | Repo, Status, Screenshots, Mitmachen |

Nächster sichtbarer Schritt: Package-Skelett, Sample-App, erste Screenshots.

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
