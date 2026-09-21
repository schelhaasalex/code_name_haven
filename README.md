# Reclaim

**The people in the room matter more than the ones in your pocket.**

A phone-free ritual app for iOS. One person sets their phone down and everyone
else's answers — a chime, a screen going dark across the table, a count that
climbs. The place you did it in slowly becomes something.

Not restriction with a nicer font. Nothing here blocks an app, locks a box, or
shows you a shame chart. See [VISION.md](VISION.md) for why that matters.

---

## Status

| | |
|---|---|
| **Database** | Live and tested. Five migrations applied to the hosted project; 16 assertions pass against a scratch Postgres; Supabase's linter reports nothing. |
| **iOS app** | Written, **not yet compiled.** Authored without a Swift toolchain — see [docs/BUILD-NOTES.md](docs/BUILD-NOTES.md) for where errors will concentrate. |
| **Tests** | `supabase/tests/` runs green. The Swift suite in `ReclaimKit/Tests/` is written and, like the app, **not yet run.** |
| **Design** | 21 screens plus an IA map, on a canvas. Every string extracted to `copy/strings.json`. |
| **Ceremony** | A working web rehearsal in `prototype/` — the one thing no mockup can test. |

Not yet built: screen 9 (a place and its arc), 15 (the printed card), 21
(naming a place), in-app NFC writing, and the iOS 18 Control Centre control.

## Running it

```sh
brew install xcodegen
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # add the key
xcodegen generate
open Reclaim.xcodeproj
```

The Supabase URL is already in the example file; the publishable key is in the
dashboard under **Settings → API**. `Reclaim.xcodeproj` is generated and not
committed — adding a Swift file needs no project edit.

**Running on a physical device** needs an Apple Developer membership for Sign
in with Apple, App Groups, NFC and Associated Domains. *Individual* enrollment
is enough — no business entity, no D-U-N-S number.

Database tests, against any local Postgres:

```sh
supabase/tests/run.sh
```

Swift tests — formatting, copy, handles, the dot calendar, the retroactive
offer, and which interruption wins:

```sh
# ReclaimKit imports UIKit and ActivityKit, so the tests need a simulator —
# `swift test` cannot build the package for macOS.
xcodebuild test -scheme ReclaimKit \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or open `ReclaimKit/Package.swift` in Xcode and press ⌘U.

## What's where

```
VISION.md            why this exists
BRIEF.md             what it is — metrics, stack, mechanics, decisions made
CLAUDE.md            the rules, for anyone (or anything) writing code here
docs/
  APP-SPEC.md        how the app is built: targets, data layer, screens
  SCHEMA-REVIEW.md   fourteen bugs found before any of this shipped
  BUILD-NOTES.md     first-build gotchas
  STYLE.md           how the code is shaped, and what is worth testing
copy/strings.json    every user-facing string — the primary brand asset
supabase/            migrations (applied, tested) and the test harness
prototype/           the web rehearsal of the five-phone moment
ReclaimKit/          shared package: models, data, ceremony, copy, design
Reclaim/             the app
ReclaimWidgets/      the Live Activity and its End button
```

## Two rules worth knowing before you read any code

**The client never reads another person's rows.** `sessions` and `profiles` are
own-rows-only at the database. Anything crossing a person boundary goes through
an RPC returning an aggregate. RLS cannot express *"readable in aggregate but
not enumerable"*, so this rule is the only thing holding up the promise that
the people you dock with see that you were there, never how often you weren't.

**The count goes up, never down.** The app has no roster of who is present —
only a list of who joined. It shows presence, never absence, and never names
someone who hasn't put their phone down. That screen would be both impossible
to build honestly and the exact nagging instrument this product replaces.

The other five are in [CLAUDE.md](CLAUDE.md).

## Testing the database is not optional

Five of the fourteen findings in the schema review were invisible on reading
and obvious on executing — three against local Postgres, two only against
hosted Supabase. Among them: a column grant that didn't do what it looked like
and left the join secrets readable, and an extension in the wrong schema that
would have failed at runtime on the first card scan and nowhere earlier.

Run the SQL. Don't read it and believe yourself.

## Scope

The app is free. The business is the puck — a small object by the door that
makes the gesture physical. Everything in v1 (the printed card, the tag, the
tap) is that object's software ancestor on purpose.

Out until explicitly asked for: the BLE/NFC puck, geofencing, Android,
office/B2B mode, parent mode, and payments of any kind.
