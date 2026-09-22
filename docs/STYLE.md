# Style

How code in this repository is shaped. `CLAUDE.md` has the seven rules that are
about correctness; this is about keeping the thing workable.

---

## Views

**One view per file, named for the file.** `HomeView.swift` contains `HomeView`
and nothing else public. A private helper used only by that screen may live
beside it; the moment a second file wants it, it moves to `Components/`.

**A `body` longer than about 40 lines is a smell.** Not a hard limit — a smell.
Extract when a chunk has a name you'd say out loud ("the suggestion row", "the
week of dots"), not to hit a number. Extraction that produces
`private var section1: some View` has made things worse.

**Two levels of extraction, in order:**

1. `private var` / `private func` in the same file — for a piece only this
   screen will ever draw.
2. A real component in `Components/` — the moment a second screen wants it, or
   the piece has a name and behaviour of its own.

Skipping straight to (2) for everything produces a component library nobody can
navigate. Staying at (1) forever produces the 400-line view.

**Screens don't do layout chrome.** Background, gutters and safe area come from
`.ground(night:)`. A screen that sets its own padding is fighting the modifier.

## Components

Live in `Reclaim/Components/`, one per file. Before adding one, check whether an
existing component takes a parameter instead — `PaperCard` with a different
corner radius beats `RoundedPaperCard`.

The current set:

| Component | For |
|---|---|
| `Brand` | The ring-and-dot mark |
| `Eyebrow` | Mark + letterspaced caps, the header on nearly every screen |
| `PhoneSlab` | One phone at the table; fills on join, turns over on face-down |
| `PrimaryButton` / `QuietButton` | The two button weights, paper or night |
| `PaperCard` | The bordered off-white block |
| `NightCard` | Its dark counterpart |
| `LabelledSection` | Eyebrow + a stack, used throughout settings and places |
| `StatRow` | Label on the left, a display-face number on the right |
| `DotWeek` | The week of dots on Home's footer |
| `Ground` | The paper or night ground, gutters, safe area |

**A component takes data, not `AppState`.** `PhoneSlab(name:isMe:isDown:)`, not
`PhoneSlab(member:state:)`. Screens read state; components render what they're
handed. This is what makes every component previewable in isolation and keeps
them from quietly acquiring behaviour.

**No literal colors or font sizes in a view.** `Palette` and `Type` only. A size
that isn't on the scale in `Type` is either a mistake or belongs on the scale.

## State

One `@Observable AppState` on the environment. No Composable Architecture, no DI
container, no view models per screen — at 21 screens each is more machinery than
the thing it manages.

A screen may hold `@State` for something only it cares about (a text field, a
sheet flag, a step in a local flow). It may not hold a copy of anything in
`AppState`; read it.

Mutations go through `AppState` methods, never by a screen calling the
repository directly. There's one exception by design — the interruption screens
call `repo.delete(session:)` and `repo.recordRetroactive` — and it's an
exception worth removing when those grow.

## Naming

- Screens: `ThingView`, matching the canvas. `HomeView` is screen 2.
  `SplashView` is screen 0 and is the one screen with no canvas — it is an
  overlay on `RootView`, not a case of `AppState.Phase`, because it must not be
  something the app can be stuck in. Two other splashes were built beside it and
  cut; `prototype/splash.html` still runs all three, which is where comparing
  them belongs.
- Components: the noun. `PhoneSlab`, not `PhoneSlabView`.
- Copy keys: `screen.element`, lowercase, dot-separated.
- Booleans read as assertions: `isLive`, `hasBeenOffered`, `restDayAvailable`.
- No `Manager`, `Helper`, `Util`, or `Service` in a type name. If that's the
  only word that fits, the type is doing too much.

## Tests

The database owns the invariants — one live session per person, one open
gathering per place, crediting at the cap — and they're asserted in
`supabase/tests/`. **Don't re-implement those checks client-side.** Let the call
fail and handle the error.

So what's left to test in Swift is thin, and it's all pure:

- **Formatting.** `Say.count`, `Say.duration`, `Say.spokenDuration`. These
  appear in user-facing copy, so a wrong plural is a visible bug.
- **Copy substitution.** A missing key, an unreplaced `{token}`.
- **Handles.** Generated handles must satisfy the database's
  `places_handle_format` check, or `create_place` fails at runtime with a
  constraint violation nobody will connect to the generator.
- **Dates.** `EveningCalendar` — the dot week and the four-week grid. Week
  boundaries, month boundaries, "distinct dates" behaviour.
- **Stationary runs.** The retroactive-credit candidate logic, separated from
  CoreMotion so it can be run on a table of fixtures.
- **Interruption precedence.** Which of the four surfaces when several qualify.

**Extract pure logic so it can be tested.** If a piece of reasoning is worth a
test and lives inside a view or behind a framework, move it to `ReclaimKit` as a
function over plain values. That's how `EveningCalendar`, `StationaryRuns` and
`Interruption.first` came to exist — date arithmetic inside two `View`s, run
detection inside a `CMMotionActivityManager` callback, and a precedence order
buried in an `AppState` method that needed a network, a sensor and a signed-in
person to reach.

Where a step is what triggers a permission prompt — asking CoreMotion, asking
for notifications — pass it in as a closure rather than a value, so the order
in which it *isn't* called is testable too.

**Don't test SwiftUI layout.** Snapshot tests of a design that's still moving
cost more than they catch.

XCTest, because it works on every Xcode. Swift Testing is nicer and worth
switching to once Xcode 16 is the floor.

```sh
# ReclaimKit imports UIKit and ActivityKit, so the tests need a simulator —
# `swift test` cannot build the package for macOS.
xcodebuild test -scheme ReclaimKit \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Or open `ReclaimKit/Package.swift` in Xcode and press ⌘U.

Nothing under test needs a simulator — it is all functions over plain values —
but the package it lives in does, because `Sensation` imports UIKit and the
Live Activity imports ActivityKit. Splitting a pure `ReclaimCore` out would buy
`swift test` and a CI job that needs no Mac. Worth doing the day there's CI,
not before.

The suite was authored without a Swift toolchain and **has not been run yet**.
Expect the first pass to surface signature and inference errors rather than
failures of logic; `docs/BUILD-NOTES.md` says where.

## Files and size

Rough shapes, not rules:

- A view file over ~150 lines usually has a component hiding in it.
- A type with more than one reason to change is two types.
- `ReclaimKit` holds anything both targets need, anything worth testing, and
  anything that would otherwise be duplicated. Everything else stays in the app.

## Keeping it this way

This guide is the second draft of itself. The first one was written on a
Tuesday over a repository that broke six of its own rules, by the person who
had just written them — which is the whole argument for the paragraph below.

Anything here that a script can decide, a script decides: `scripts/shape.sh`.
It reads text, needs no toolchain and takes about a second. Three places run
it, in increasing order of how annoying it is to reach:

1. **While writing.** A `Stop` hook in `.claude/settings.json` runs it before a
   session here can end.
2. **On the branch.** `scripts/shape.sh` by hand, or the checkbox on the pull
   request template.
3. **In CI.** `.github/workflows/checks.yml`, on every pull request, alongside
   the schema tests.

## Sensors and radios

A sensor proposes; a person decides (rule 4). Nothing a sensor hears may start,
end or credit an evening on its own — the most it can do is put a question on
screen, and the most a refused permission may cost is that question.

Anything that talks to another phone follows the same shape as `Nearby`:

- **What travels is a key, not an address.** A place id works forever; a key
  minted for one evening is worthless the moment it ends. If a value picked up
  off a radio would still let someone in tomorrow, it is the wrong value.
- **Believe the shape before the content.** Any device can advertise our ids
  and answer with anything. Bytes off the air are checked against what one of
  ours looks like (`Nearby.key`) before they ever reach a request.
- **Ask when the question makes sense.** The Bluetooth prompt happens at the
  dock, because "so the phones around you can find this table" only means
  something a second after somebody set a phone down. The scanner stays silent
  until then rather than prompting someone who has just signed in.
- **Listen in the foreground, talk in the background.** The phone in a hand is
  the one about to be put down; the phone already down is the one that has to
  keep saying so.

The rule for the rules: **adding one here means adding a check there.** If it
can't be checked, say so in the same breath, so the next person knows it rests
on attention rather than on the build. The checks that exist are listed in
`CLAUDE.md`; each one is there because this repository broke it at least once.

And write the check so it fails first. A check that has never gone red is a
check nobody has tested — two of these were silently passing on everything
until they were pointed at a file built to break them.

## Comments

Comment the decision, not the mechanics. `// loop over members` is noise;
`// The count goes up, never down — the app has no roster` is the reason
somebody won't undo it in six months.

Every non-obvious constraint in this codebase came from a real bug. When you
work around one, say which.
