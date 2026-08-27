# Contributing

Thanks for looking at Bimbel.

## Scope

Bimbel is a native iOS chat *component*, not a full messenger. In scope: conversation list, chat thread, bubbles, composer, keyboard, replies, media in a thread. Out of scope: Status, Calls, Settings, accounts, backend — unless the component API needs a hook for it.

The repo also ships a minimal sample app that embeds the component (tests + something to look at).

Agent-friendly usage (Swift Package, small public API, example) is in scope. Treat coding agents as a first-class consumer.

## How to help

1. Open an issue first if the change is more than a small fix.
2. Keep PRs small and focused on the component.
3. UI changes need a screenshot (simulator or mock).
4. Swift / SwiftUI, Xcode, iOS 17+ unless the issue says otherwise.

## Local setup

Xcode, then open the sample app once it lands on `main`. Until then, research and UI notes are the useful contributions.
