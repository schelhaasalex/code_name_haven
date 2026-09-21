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

Both channel kinds are private, authorised by the policies in `0006`
(schema review, finding 15). A private channel needs a signed-in user, so the
unauthenticated two-client check above no longer works — by design.

Nothing awaits a channel. A refused or unreachable subscribe is retried by the
SDK — five attempts, ten seconds each — so `AppState` hands joining, announcing
and watching to `CeremonyLink`, which runs them in order off to the side. The
chime, the face-down sensor, `SessionFlag` and the Live Activity no longer wait
a minute behind a channel (rule 7). `CeremonyLinkTests` holds joins open to
check the races: ending mid-join, and starting again before the first lands.

`load()` runs on every return to the foreground, so it reconciles rather than
reloads (`Reconciliation`): the same evening is refreshed, not restarted; one
ended elsewhere ends here; and a failed read changes nothing. Offline is not
signed out, and not "nothing is running".

## Starting and ending without opening the app

Three things were wrong here and none of them showed up as an error:

- **The End button and the Control Centre toggle did nothing.** A plain
  `AppIntent` run from a widget or control executes in the extension's
  process, where `IntentEnvironment.repository` is nil and the Supabase session
  isn't visible. All three intents are now `LiveActivityIntent`s, which run in
  the app's process — Apple's own control example is `SetValueIntent,
  LiveActivityIntent` for the same reason.
- **`IntentEnvironment.onSessionChanged` was never assigned.** It now calls
  `load()`, which reconciles: an evening started by Siri is adopted, one ended
  by the Live Activity is ended here. `LiveActivityController.end()` ends every
  activity, because a background relaunch doesn't remember the one it's ending.
- **The Siri phrases were never registered.** Declared in ReclaimKit, the
  intents were extracted but `autoShortcuts` in the app's
  `Metadata.appintents/extract.actionsdata` was empty. `ReclaimShortcuts` now
  lives in the app target, and `scripts/shape.sh` keeps it there. That file is
  the thing to read if the phrases ever go missing again.

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

## Seeing it before sign-in works

Sign in with Apple needs a paid developer team, so until then the real app
stops at Welcome. Pick the **Reclaim (Sample data)** scheme instead: it launches
with `-sample-data`, and `ReclaimApp` swaps in `PreviewRepository.sampleHousehold()`
— Alex, Maya and Dad, three places, a few weeks of evenings. Starting and ending
an evening work, in memory, following the database's rules (one live evening,
three-hour cap, fifteen minutes to count). Nobody else's phone is there, so
every evening started in it is just you. Every launch starts fresh.

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
