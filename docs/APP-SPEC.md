# Reclaim — iOS implementation spec

How the native app is put together. `VISION.md` says why; this says what is
built. The box itself — the drawer, its slots, its radio — is `docs/DOCK.md`.
The schema is in `supabase/migrations/`.

The app is the box's. Putting your phone in it starts your evening; taking it
out ends it, fifteen seconds later. Everyone whose phone is in the same box is
in the same evening. The lock screen and the wrist show the evening charging,
and Home shows what the box has kept. Nothing else starts an evening, and
there is nothing to set up but meeting the box once.

Deployment target **iOS 17.0**: Live Activities that a push can start need
17.2, and the Watch face needs 18; both are conditional, never a reason the
evening doesn't count.

---

## Targets

| Target | What's in it |
|---|---|
| **Reclaim** | The app. SwiftUI views, the store, the box's links, the Live Activity controller. |
| **ReclaimWidgets** | Widget extension: the Live Activity, on the lock screen, the Dynamic Island and the Watch. |
| **ReclaimKit** | Local Swift package. Models, the repository, the box's protocol and links, copy, design. Imported by both targets. Anything testable lives here. |

Entitlements: Associated Domains (the box's links open the app), Push (the
server starts and steps the Live Activity), and Sign in with Apple (only for
"Keep your evenings" in Settings). Background mode: `bluetooth-central`
only, for the standing connection to the box. The camera is asked for only
when someone taps "Scan the card".

Dependencies: **`supabase-swift` only.**

---

## Package layout

```
ReclaimKit/Sources/ReclaimKit/
  Models/        Session, Gathering, Place, Profile, Member, PlaceSummary, EveningTotal
  Data/          Repository (protocol), SupabaseRepository, PreviewRepository
  Dock/          Box (the Portside protocol, "was it me"), BoxLink (the radio),
                 BoxPairing, Dock (links), DockSlot, DockLight + WLED (the lights)
  Activity/      ReclaimActivityAttributes, EveningCharge, RemoteActivity
  Support/       AutoClosed, BoxStage, Reconciliation, EveningCalendar,
                 EveningLanding, EveningMarkLayout, Handle, Links, Splash
  Copy/          Copy.swift
  Design/        Palette, Typography

Reclaim/
  AppState.swift            @Observable, the one store
  AppState+Evening.swift    start, adopt, reconcile, end
  AppState+Box.swift        the radio: a slot filled, a slot emptied
  AppState+Boxes.swift      this phone's boxes: meeting, naming, forgetting
  AppState+Dock.swift       the tag and the code; the foreground check
  Screens/                  one file per screen
  Components/               take data, never AppState
  Entry/                    URLRouter, ChargingWatch, LiveActivityController

ReclaimWidgets/
  ReclaimLiveActivity.swift, ReclaimLiveActivityOnWrist.swift,
  ActivityFace.swift, WristActivity.swift, RingMark.swift
```

---

## Data layer

`Repository` is the whole of what the app can ask for. **The client never reads
another person's rows** (CLAUDE.md rule 1): your own profile, places, sessions
and gatherings directly; anything about anyone else — who's in the box with
you, what the box has kept — through an RPC that returns an aggregate.

Accounts are made silently: `signInAnonymously()` on the first launch, and the
profile row with it. **Anonymous sign-ins must be enabled in the project's Auth
settings.** An anonymous account goes with the app, so Settings offers — never
asks — "Keep your evenings": Sign in with Apple linked to the same account
(`keep`, which needs **Allow manual linking** on in Auth settings). An Apple ID
that already keeps another account is offered as a switch, not taken.

Deleting the account is the server's (`delete_my_account`, 0020): any evening
running ends, the login goes and the profile with it, and the evenings stay in
the boxes' totals owned by nobody — the hours a house spent at its box are its
own.

| Call | For |
|---|---|
| `dockPlace(secret:handle:)` | The box's place, found or made by whoever reads its tag or code first, and the reader one of its people (0013, 0017) |
| `startOrJoin(place:source:)` | The phone went in: join the box's open evening, or open it |
| `endSession(_:)` | The phone came out. Returns the minutes credited, capped |
| `members(of:)` | Who's in the evening — a count on screen, never a roster |
| `summary(of:)` | The box's whole life: evenings, hours together, its stage |
| `myEvenings()` | Your own evenings, as days |
| `saveActivityToken`, `startActivityRemotely`, `saveLiveActivity` | The Live Activity's pushes (0015, 0016) |

---

## State

One `AppState` on the environment. It holds the evening (`session`,
`gathering`, `members`, `startedAt`), the boxes (`boxPlaces` in the order they
were met, `lastBox`, `boxSummaries`; `boxPlace` is the one Home leads with), your
evenings (`evenings`, `eveningTotal`), and the two things that surface over
Home: `justEnded` (screen 8) and `closedForYou` (screen 13).

`load()` runs at launch and on every return to the foreground. It makes the
account if there isn't one, reconciles what the phone thinks is running with
what the database says (`Reconciliation`), and runs the foreground check
(below). A failed read keeps what was known: offline is not "nothing is
running".

---

## Screens

| # | Screen | View | |
|---|---|---|---|
| 0 | Splash | `SplashView` | over everything, on its own clock |
| 2 | Home — the box, what it has kept, your week | `HomeView` | root |
| 2a | Meet your box | `HomeView`, no box yet | root |
| 2b | Scan the card — the camera, then pairing | `ScanView` | full screen, from 2a |
| 6 | In the box — with others, or alone | `SessionView` | root while live |
| 8 | The receipt | `SessionEndView` | root, once, after an evening |
| 13 | We closed this one for you | `AutoClosedView` | sheet over Home |
| 16 | Settings — your boxes, keeping your evenings, how it works, deleting the account | `SettingsView` | push |
| 16a | One box — its name, what it has kept, its radio, Forget | `BoxView` | push from 16 |
| — | No network on the first launch | `UnreachableView` | root |
| 7 | Lock screen, Dynamic Island, Watch | Live Activity | `ReclaimWidgets` |

There is no button that starts an evening, no tab bar, and no End: the box is
the only switch. `scripts/shape.sh` fails any call that starts one from
anywhere but the box's radio and its tags.

**Home** centres on the evening mark: a dot for every evening you've had,
outward from your first, with today's last — an outline until today has
counted, then filled, and the line beside it goes from *Ready when you are.*
to *Today counts.* Above it, the box this phone was last at and the part of
the day. Below it, quietly, what each box has kept (`place_summary`'s hours
and evenings, a line each — tracked and said, not the reason to set the phone
down), and your week as dots. The ring is the lock screen's; the mark is
Home's, and the receipt is where tonight's dot joins it. Nothing claims a
number before the database has said one.

An unnamed box goes by The Harbor, The Cove or The Mooring, in the order the
house met them. The first phone to read it writes that name down, so every
phone calls it the same thing; renaming is Settings.

**The receipt** says when, how long and with how many, then your evenings with
tonight's landing among them. **The evening screen** is rarely seen — a phone in
a hand that isn't charging has left the box — so it says only who's there and
since when, and that the evening ends when the phone comes out.

---

## The box

`docs/DOCK.md` has the hardware and the protocol. In the app:

**Meeting it.** The box's code (`/p/<secret>`, printed on the card that comes
with it) is read by the app's own scanner (screen 2b, "Scan the card" on
Home), or by the Camera app, which opens the app through Associated Domains —
as does any slot's tag (`/p/<secret>/<slot>`). With the app not installed the
same link is a page saying to get it and scan the card from inside (`links/`). Either,
read first, finds or makes the box's place and makes this phone one of its
people; the app then listens for docks for three seconds and keeps the closest
(`Box.closest`) as its radio — on every read, so a box whose board was
swapped under the same card is found again. The scanner shows those seconds:
*Listening for your box.*, *There it is.* — or *Not hearing it yet*
and a retry. A tag also starts the evening: it's read with
the phone going into the slot. The code starts nothing.

**In.** The box notifies every connected phone that a slot filled. Each asks
itself whether that was it (`Box.isThisPhone`: it has just started charging,
and the box is close), and the one that was starts the evening at the box's
place. iOS won't let a background app start a Live Activity, so the phone
asks the server to start it by push.

**Out.** A slot empties. Every phone in the box waits `Box.outGrace` — fifteen
seconds, room to put a slipped phone back — and the one that still isn't
charging ends its evening. The same check runs on every return to the
foreground, for a phone whose wake was missed: in a hand and not charging is
out. An evening nobody ended — a phone left in overnight — is closed by the
server at three hours, and screen 13 says so once.

---

## The Live Activity

Started by the app when it's awake, or by push when the box started the
evening in the background (`start-live-activity`, migration 0015). Ended by the
app when the phone comes out, and by the server for an evening it closed.

```swift
struct ContentState: Codable, Hashable {
    var startedAt: Date
    var memberCount: Int
    var placeName: String?   // nil reads "Your box"
    var stage: Int           // 0–4, the ring's segments
}
```

Lock screen: the ring-and-dot mark, *"See you in a bit."* alone or
*"Three of you so far."* together, and *"The Kitchen Table · since 7:27"*.
**No ticking digits and nothing to press.**

**The evening charges.** The ring is four segments, full at fifteen minutes,
half an hour, an hour and an hour and a half, and then it holds. A light joins
it for each person in the box, and the mark warms from the hour. It only
fills. Nothing creeps — the ring changes four times in an evening, each step
pushed by the server (`charge-live-activities`, once a minute, migration
0016), because the phone is asleep in the box when it happens.

Watch (iOS 18, watchOS 11): the same activity in the Smart Stack — the ring,
a headline for its step (*"Settling in."*, *"Tonight counts."*, *"Unwinding."*,
*"Present."*, *"Recharged."*) and *"Three of you · since 7:27"*.

---

## Copy

Every user-facing string lives in `copy/strings.json`, keyed `screen.element`,
bundled with the app. **Never hardcode a user-facing string in a view.**

```swift
Text(t("home.body"))   // "Put your phone in the box. That's all there is to it."
```

---

## Testing

`ReclaimKit/Tests` covers what's decided in Swift: the protocol's bytes and
events, "was it me", pairing by the closest dock, the links, the ring's steps,
the receipt's landing, reconciliation, formatting and copy. The database owns
the invariants — one live session per person, one open gathering per place,
crediting at the cap — and `supabase/tests/` executes them. Don't re-implement
those client-side; let the call fail.
