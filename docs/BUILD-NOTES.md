# First build

```sh
brew install xcodegen
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # fill in the key
xcodegen generate
open Reclaim.xcodeproj
```

The Supabase URL is already correct in the example file. Get the publishable
key from the dashboard under **Settings → API**.

## Expect compile errors on the first pass

This was written without a Swift toolchain — the container it was authored in
is Linux, with no Xcode and no iOS SDK. Every line is unverified by a compiler.
That's a real difference from the SQL, where five bugs were found by actually
running it.

Two files touch supabase-swift's API and are where problems will concentrate:

- `ReclaimKit/Sources/ReclaimKit/Data/SupabaseRepository.swift`
- `ReclaimKit/Sources/ReclaimKit/Ceremony/CeremonyTransport.swift`

The shapes to check first: `client.channel(_:)`, `channel.broadcastStream(event:)`,
`channel.broadcast(event:message:)`, and whether `.execute().value` infers the
decode target in each RPC. Realtime is deliberately behind the
`CeremonyTransport` protocol, so if the API differs it's ~40 lines to fix and
`AppState` doesn't change.

Everything else is Foundation, SwiftUI, CoreMotion, ActivityKit and AppIntents.

The same caveat covers `ReclaimKit/Tests/` — the assertions were reasoned
about, not executed. Run them first:

```sh
xcodebuild test -scheme ReclaimKit -destination 'platform=iOS Simulator,name=iPhone 16'
```

They need no key and no network, so they are the cheapest thing to get green.
They do need a simulator: `swift test` can't build ReclaimKit for macOS,
because `Sensation` imports UIKit and the Live Activity imports ActivityKit.

`CopyTests` reads `copy/strings.json` from the repository through `#filePath`
rather than from the bundle, so it fails loudly if the file moves instead of
passing against a stale bundled copy — and it asserts the two are identical,
which is the failure mode of keeping the same file in two places.

## What is and isn't here

**Built:** the whole data layer with previews, copy loading, design tokens, the
handle/secret generator, the ceremony transport and face-down sensor, the
chime and haptics, app intents with free Siri phrases, the Live Activity with
its working End button, and screens 1, 2, 3, 5, 6, 8, 10, 11, 12, 13, 14, 16,
17, 18 and 20.

**Not yet:** screen 9 (a place and its arc), 15 (the printed card), 19's
in-app NFC *writing* (reading via universal link is wired), 21 (naming a
place), the Control Center control (iOS 18, `ControlWidget`), and merging two
places from the UI — `merge_places` exists in the database and has no screen.

**Needs an Apple Developer account before it will run on a device:** Sign in
with Apple, App Groups (the app↔widget bridge), NFC, Associated Domains.
Individual enrollment is enough — no business entity, no D-U-N-S.

## Fonts

Fraunces and Work Sans are both OFL. Until the `.ttf` files land in
`Reclaim/Resources/Fonts`, `Type` falls back to the system serif and sans, so
the app builds and runs from the first commit. `Type.isCustom` says which
you're looking at.

## The one that will bite quietly

`state.evenings` drives both the dot week on Home and the grid on screen 10.
It loads 35 days of the signed-in user's own sessions and reduces them to
distinct `local_date` strings — **distinct**, because a five-person dinner is
one evening, not five. If those numbers ever look 5× too high, that's the line
that broke.
