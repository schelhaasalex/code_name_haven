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

Four newer spots touch framework API shapes worth checking early:

- **`SetItDownControl`** — `ControlWidgetToggle`'s title. If it won't take a
  `String`, wrap it: `LocalizedStringKey(t("control.title"))`. Controls are
  iOS 18, so this needs the Xcode 16 SDK to compile at all; the `if #available`
  in the widget bundle relies on `WidgetBundleBuilder.buildLimitedAvailability`.
- **`TagSession`** — `NFCNDEFPayload.wellKnownTypeURIPayload()` is a method on
  read and a static initialiser on write. Easy to get backwards.
- **`CardView`** — `ImageRenderer` + `ShareLink(item:preview:)` with an
  `Image`. If `SharePreview(_:image:)` rejects a `String` title, pass `Text`.
- **`PlaceSecrets`** — Keychain access needs the app's entitlements in place;
  on the simulator it works unsigned, on device it needs the profile.

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

**Built:** all 21 screens, the data layer with previews, copy loading, design
tokens, the handle/secret generator, the ceremony transport, the place
invitation channel behind screen 4, face-down detection, the chime and
haptics, app intents with free Siri phrases, the Live Activity with its
working End button, the iOS 18 Control Centre toggle, tag reading and writing,
the printable card, naming, and merging two places.

**Not yet:** the fonts (see below), and anything that needs a device.

**Needs an Apple Developer account before it will run on a device:** Sign in
with Apple, App Groups (the app↔widget bridge), NFC (`NDEF` in the
entitlements), Associated Domains (`applinks:reclaim.app` — a domain you
control has to serve `/.well-known/apple-app-site-association` before a
background tag read can work). Individual enrollment is enough — no business
entity, no D-U-N-S.

**The simulator can't do NFC.** `NFCNDEFReaderSession.readingAvailable` is
false there, so `TagSession` returns a failure immediately and the card screen
says the tag didn't take. That is correct behaviour, not a bug to chase.

## Fonts

Fraunces and Work Sans are both OFL. Until the `.ttf` files land in
`Reclaim/Resources/Fonts`, `Type` falls back to the system serif and sans, so
the app builds and runs from the first commit. `Type.isCustom` says which
you're looking at.

## The card can only be drawn where it was made

`places.join_secret_hash` is a hash, so the plaintext secret lives only in the
Keychain of the device that minted the place. Screen 15 on any other device
says so rather than drawing a square that opens nothing. If a card seems
"missing" in testing, that is why — and it is the design, not a lost write.

## The one that will bite quietly

`state.evenings` drives both the dot week on Home and the grid on screen 10.
It loads 35 days of the signed-in user's own sessions and reduces them to
distinct `local_date` strings — **distinct**, because a five-person dinner is
one evening, not five. If those numbers ever look 5× too high, that's the line
that broke.
