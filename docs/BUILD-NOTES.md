# First build

```sh
brew install xcodegen
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # fill in the key
xcodegen generate
open Reclaim.xcodeproj
```

The Supabase URL is already correct in the example file. Get the publishable
key from the dashboard under **Settings → API**.

## Where the first compile landed

This was written without a Swift toolchain, on Linux, and first went through a
compiler on Xcode 26 / the iOS 26 SDK. It needed four fixes, none in the two
supabase-swift files everyone expected to break:

- a rename that hadn't reached `CardView` (`TagWriter` → `TagSession`)
- a doubled optional binding in `AppState.load()`
- `adopt(session:)` was `private` in one file and called from another
- `CopyTests`' list of known `{tokens}` was missing `from` and `to`

The one that mattered was not a compile error. **Every Info.plist key lives in
`info.properties` in `project.yml`, never as an `INFOPLIST_KEY_*` build
setting.** Those settings only apply when Xcode generates the plist; XcodeGen
writes it, so they were silently dropped — no launch screen (the app ran
letterboxed), no motion or NFC usage strings (iOS terminates an app that reads
motion history without one), and Live Activities switched off.

## Realtime, fixed and checked live

Both halves of the round trip were wrong and neither threw, so every ceremony
event and every invitation was dropped at a `continue`. `broadcastStream(event:)`
yields the whole envelope (`event`/`payload`/`type`), not what was sent, and
`broadcast(event:message:)` writes dates as ISO-8601 strings that a plain
`JSONDecoder` can't read. The wire format now lives in `CeremonyWire`, where
`CeremonyWireTests` runs it through the SDK's own encoder.

Checked against the hosted project with two clients: the old transport
received nothing, the new one delivers both. Subscribing now uses
`subscribeWithError()`, and leaving removes the channel, because the client
caches channels by topic and would hand a dead one back on the next join.

## Compiles, but known to be wrong

Found by reading, not yet fixed. None of these shows up as an error — each
fails silently:

- **The Live Activity's End button and the Control Centre toggle.** A plain
  `AppIntent` run from a widget executes in the extension's process, where
  `IntentEnvironment.repository` is nil and the Supabase session (in the app's
  Keychain) isn't visible. `LiveActivityIntent` runs in the app's process.
- **`IntentEnvironment.onSessionChanged` is never assigned**, so a session
  started from Siri doesn't reach `AppState`, the Live Activity or
  `SessionFlag`.
- **Siri phrases.** `ReclaimShortcuts` lives in the package; App Intents
  metadata is extracted per target, so it may need to move into the app.

Still unexercised: anything behind sign-in (needs the real publishable key),
NFC (the simulator has none) and anything needing a signed device build.

Run the Swift tests with:

```sh
xcodebuild test -scheme ReclaimKit -destination 'platform=iOS Simulator,name=iPhone 17'
```

They need no key and no network, so they are the cheapest thing to keep green.
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
