# Reclaim — iOS implementation spec

How the native app is put together. `BRIEF.md` says what it is and why;
this says what to build. The schema is in `supabase/migrations/` and the
screens are on the canvas linked from the brief.

Deployment target **iOS 17.0**, forced by the interactive End button on a
Live Activity. Note one consequence: **Control Center controls need iOS 18**
(`ControlWidget`), so that entry point is conditional, not baseline.

---

## Targets

| Target | What's in it |
|---|---|
| **Reclaim** | The app. SwiftUI views, app intents, the Supabase client. |
| **ReclaimWidgets** | Widget extension: the Live Activity, the home-screen widget, and (iOS 18+) the Control Center control. |
| **ReclaimKit** | Local Swift package. Models, repository, copy, the ceremony engine. Imported by both targets. |

The three-way split exists from commit one because the Live Activity and the
app must share model types and the End intent, and retrofitting a package
boundary after the views are written is miserable.

Entitlements needed (all available on an **Individual** developer membership —
no business entity required): Sign in with Apple, App Groups, NFC Tag Reading,
Associated Domains, Push (unused, but the Live Activity capability sits near it).

Dependencies: **`supabase-swift` only.** Nothing else. No networking library,
no state framework, no DI container.

---

## Package layout

```
ReclaimKit/Sources/ReclaimKit/
  Models/        Session, Gathering, Place, Profile, Rhythm, PlaceSummary, Member
  Data/          Repository (protocol), SupabaseRepository, RPC wrappers
  Ceremony/      CeremonyEngine, FaceDownSensor, Haptics, Chime
  Copy/          Copy.swift, strings.json (bundled fallback)
  Intents/       StartSessionIntent, EndSessionIntent, ReclaimShortcuts
  Activity/      ReclaimActivityAttributes

Reclaim/
  ReclaimApp.swift
  AppState.swift            @Observable, the one store
  Screens/                  one file per screen, named for the canvas
  Components/               PhoneSlab, TableRow, StageBar, DotWeek, Brand
  Entry/                    NFCHandler, URLRouter, notification scheduling

ReclaimWidgets/
  LiveActivityView.swift
  ReclaimControl.swift      @available(iOS 18)
  ReclaimWidgetBundle.swift
```

---

## Data layer

Models mirror the SQL exactly; `Codable` with `convertFromSnakeCase`.

**The hard rule, enforced by RLS and repeated here so nobody works around it:
the client never reads another person's rows.** `sessions` and `profiles` are
own-rows-only at the database. Everything cross-person comes back from an RPC.
If a view needs someone else's data and there's no RPC for it, the answer is a
new RPC, not a wider policy.

```swift
public protocol Repository {
    // own rows, direct table reads
    func myProfile() async throws -> Profile
    func myPlaces() async throws -> [Place]
    func mySessions(since: Date) async throws -> [Session]

    // anything crossing a person boundary — RPC only
    func startOrJoin(place: UUID?, source: SessionSource) async throws -> UUID
    func endSession(_ id: UUID?) async throws -> Int?
    func recordRetroactive(from: Date, to: Date) async throws -> UUID
    func gatheringMembers(_ id: UUID) async throws -> [Member]
    func placeSummary(_ id: UUID) async throws -> PlaceSummary
    func myRhythm() async throws -> Rhythm
    func resolvePlace(secret: String) async throws -> UUID?
    func createPlace(handle: String, secret: String, name: String?) async throws -> UUID
    func nameSomewhere(handle: String, secret: String, name: String) async throws -> UUID
    func mergePlaces(from: UUID, into: UUID) async throws
}
```

`startOrJoin` always passes the device's current timezone identifier so
`local_date` is computed correctly server-side. A session credits to the day it
**started**.

Provide a `PreviewRepository` with fixtures so every screen builds in Xcode
previews without a network.

---

## State

One `@Observable final class AppState` on the environment. No Composable
Architecture, no Redux, no DI container — at 21 screens they are all overhead.

Holds: the signed-in `Profile`, the live `Session` and its `Gathering` (or nil),
the member list for the live gathering, cached `[Place]`, the current `Rhythm`,
and a `pending: Interruption?` for the four screens that surface over Home.

```swift
enum Interruption: Identifiable {
    case autoClosed(Session)       // 13
    case rhythmEnded(Rhythm)       // 14
    case countThat(from: Date, to: Date)  // 18
    case makeItOneTap              // 20
}
```

Computed once on foreground, in this order, and at most one shown per launch.

---

## Screens

Home is the root. **No `TabView`.** Places, rhythm and settings are pushed from
Home; the interruptions are presented over it.

| # | Screen | View | Presented as |
|---|---|---|---|
| 1 | Welcome | `WelcomeView` | root when signed out |
| 2 | Ready when you are | `HomeView` | root |
| 3 | Docked, place optional | `DockedView` | full-screen cover |
| 4 | Someone started | `JoinInviteView` | full-screen cover, from the place channel |
| 5 | The count goes up | `CountUpView` | inside the session cover |
| 6 | In session | `SessionView` | inside the session cover |
| 7 | Lock screen | Live Activity | `ReclaimWidgets` |
| 8 | Session end | `SessionEndView` | inside the session cover |
| 9 | The place, and its arc | `PlaceView` | push |
| 10 | In a rhythm | `RhythmView` | push |
| 11 | Day one | `HomeView` empty state | root |
| 12 | Just you | `SessionView`, one member | — |
| 13 | We closed it for you | `AutoClosedView` | sheet |
| 14 | A rhythm ends | `RhythmEndedView` | sheet |
| 15 | The card | `CardView` (printable) | push from 9 |
| 16 | Settings | `SettingsView` | push |
| 17 | Your places | `PlacesView` | push |
| 18 | Count that? | `CountThatView` | sheet |
| 19 | Starting without unlocking | Live Activity | `ReclaimWidgets` |
| 20 | Make it one tap | `OneTapView` | sheet, after 5 evenings |
| 21 | Naming a place | `NamingView` | sheet |

3 → 5 → 6 → 8 are one `SessionFlowView` driven by session state, not separate
navigation destinations, so the session survives backgrounding.

---

## The ceremony

The heart of it. Screens 3, 5 and 6.

**`CeremonyEngine`** owns a Supabase Realtime channel named
`gathering:<uuid>`. Broadcast payloads, all absolute state, never deltas:

```
docked   { gatheringId, at }          someone started or joined
facedown { gatheringId, profileId, down }
released { gatheringId, profileId }
```

On receiving `docked`: haptic, screen transition, chime, refresh members.

**Render your own tap immediately and ignore your own echo.** Don't wait for
the round trip — the person who tapped should feel it instantly, and everyone
else feels it when it lands. That *is* the real behaviour.

**Face-down** via `CMMotionManager.accelerometerUpdates`, threshold
`z < -0.7` (normalised g). Foreground only — background accelerometer
streaming is restricted and we deliberately don't ask for it. Start updates
when the ceremony screen appears, stop on disappear.

**It is ceremony, not evidence.** Never gate anything on it. A session counts
whether the phone is face down, in a pocket, or face up and ignored.

**Haptics**: `CHHapticEngine` with a two-event pattern — a soft transient then
a continuous decay — timed against the chime. The published prototype
(`prototype/ceremony.html`, live at the canvas link in the brief) is the
reference for timing; port what the dinner test settles, don't re-derive it.

**The count goes up, never down.** The app has no roster. Show who joined;
never name who hasn't.

**A second channel, `place:<uuid>`,** carries invitations — screen 4. While no
session is running the app subscribes to the places it knows, and the person
who starts one announces themselves on that channel: gathering, place, their
own display name, and how many are down so far.

Why the name and the count travel in the message rather than being looked up:
the receiver is not a member of that gathering yet, and `gathering_members`
checks membership before it answers. There is no query they could run. So the
sender tells them, from their own row — and what they can say is bounded by
the same rule as everything else, because a count of people who HAVE set
theirs down is the only fact in the payload.

---

## Where a place's join secret lives

`places.join_secret_hash` stores SHA-256, so the plaintext exists only on the
device that minted it, in the Keychain (`PlaceSecrets`), synchronised across
that person's own devices by iCloud.

The consequence is visible and deliberate: on a device that never held it,
screen 15 cannot draw the card, and says so. The alternatives are worse —
storing plaintext server-side undoes the reason the column is a hash, and
rotating the secret would stop a card that is already printed and stuck to
somebody's fridge from working (schema review, finding 8).

---

## Entry points — the no-unlock story

The product's claim is that a session starts and ends without opening the app.

**App Intents** (`ReclaimKit/Intents`): `StartSessionIntent(place:)` and
`EndSessionIntent()`. Everything below is a thin wrapper over these two.

**Siri, free**: `AppShortcutsProvider` with phrases like
*"Start a Reclaim session"*. Needs no user setup and no paid capability.

**Action Button** (iPhone 15 Pro+): nothing to build. The user assigns the
Shortcut; our App Intent is what it runs.

**Control Center** (`ControlWidget`, **iOS 18+**): a toggle that starts and ends.
Gate it with `@available` — the app's own floor is 17.

**NFC tag**: the tag carries an **https universal link**
(`https://<domain>/p/<join_secret>`), not a custom scheme — iOS only offers to
open http(s) URLs from a background tag read. Requires Associated Domains and
a domain you control. `URLRouter` resolves the secret via `resolvePlace` and
fires `StartSessionIntent`. In-app scanning uses `NFCNDEFReaderSession` for
writing new tags.

**Live Activity** (`ActivityKit`): started when a session starts, ended when it
ends.

```swift
struct ReclaimActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var memberCount: Int
        var placeName: String?     // nil renders as "Somewhere"
    }
    var gatheringId: UUID
}
```

Lock screen: the ring-and-dot mark, the same headline as the session screen
(*"Back when you're back."* alone, *"Three of you so far."* together), *"The
Kitchen Table · since 7:27"*, and an **End** button wired to `EndSessionIntent`
— the iOS 17 feature the whole deployment target exists for. **No ticking
digits**: a face-down phone gets picked up and read here. The only thing that
moves is the mark's ring, filling once over the first fifteen minutes — a
`ProgressView(timerInterval:)`, because a Live Activity can't change at a set
moment without the app running. Dynamic Island: the mark, and the count when
there's company; expanded mirrors the lock screen.

In the app the same rule holds. Screens 3, 6 and 12 say *"Since 7:27"*, never
elapsed time, and screen 6 draws your evenings behind the headline, tonight's
dot an outline that fills at fifteen minutes. The length of the evening
appears once, on screen 8, as a receipt: *"7:27 to 9:02. An hour and a half,
all yours."*, then your evenings with tonight's landing among them.

---

## Notifications

`UNUserNotificationCenter`, scheduled locally. **No remote push, no APNs, no
tokens, no server-side send.**

Exactly one per day, at the user's chosen hour (default 19:00), never during a
live session, and **never a reminder to end one** — a buzz telling you to pick
up your phone is the app becoming the problem. Re-schedule on foreground;
cancel when a session starts.

---

## Retroactive credit (screen 18)

On foreground, query `CMMotionActivityManager.queryActivityStarting(from:to:)`
for the last 24 hours (the framework keeps about seven days). Find stationary
runs longer than the qualifying minimum that don't overlap an existing session.
Offer the longest as an `Interruption.countThat`.

Needs `NSMotionUsageDescription`. **No notification** — the card waits on Home
until the user next looks. Accepting calls `recordRetroactive`, which always
creates a solo, placeless session: nobody was broadcasting, so co-presence
can't be reconstructed and must not be invented.

---

## Copy

Every user-facing string lives in `copy/strings.json`, keyed `screen.element`.

The voice is the primary asset, so it must be changeable without an App Store
release: ship `strings.json` in the bundle as the fallback, fetch an override
table from Supabase on launch, cache it. **Never hardcode a user-facing string
in a view.**

```swift
Text(Copy["home.headline"])   // "Ready when you are."
```

---

## Milestones

1. **Skeleton** — three targets, package, Supabase client, Sign in with Apple,
   display-name capture on first authorization (Apple gives the name exactly
   once, ever).
2. **Session loop** — start, live timer, end, auto-close handling. Screens
   2, 3, 6, 8, 11, 12.
3. **Ceremony** — Realtime channel, haptics, chime, face-down. Screens 4, 5.
   *This is the one that decides whether the product works.*
4. **Live Activity + entry points** — screens 7, 19, plus intents, Siri, NFC.
5. **Places** — 9, 15, 17, 21, and the stage ladder.
6. **Rhythms** — 10, 14.
7. **The rest** — 13, 16, 18, 20.

---

## Testing

Swift Testing over the repository protocol with `PreviewRepository`. The
logic worth covering is thin, because the database owns the invariants — see
`supabase/tests/`. Focus on: the interruption precedence order, the
stationary-run detection for retroactive credit, and the ceremony state
machine's handling of a `docked` broadcast arriving before the local tap
resolves.

Everything that could corrupt data (one live session per person, one open
gathering per place, crediting at the cap) is already a constraint in
Postgres. Don't re-implement those checks client-side; let the call fail.
