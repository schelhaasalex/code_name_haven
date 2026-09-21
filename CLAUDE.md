# Working in this repository

Reclaim — a phone-free ritual app for iOS. You set your phone down, the people
around you do the same, and the place you did it in slowly becomes something.

Read `VISION.md` for why, `BRIEF.md` for what, `docs/APP-SPEC.md` for how.
`docs/SCHEMA-REVIEW.md` records fourteen bugs found before any of this shipped
and is worth skimming before touching the database.

---

## Rules that are not style preferences

These have all been arrived at the hard way. Breaking one is a bug, not a
matter of taste.

**1. The client never reads another person's rows.** `sessions` and `profiles`
are own-rows-only at the database. Everything crossing a person boundary goes
through an RPC that returns an aggregate. If a view needs someone else's data
and there's no RPC for it, write a new RPC — do not widen a policy. Screen 10
promises *"they see that you were there, never how often you weren't"*, and RLS
cannot express "aggregate but not enumerable", so this rule is the promise.

**2. No user-facing string is hardcoded.** Everything lives in
`copy/strings.json`, keyed `screen.element`, read through `Copy["home.headline"]`.
The voice is the product's primary asset; it ships as a bundled fallback and is
overridden from Supabase so it can change without an App Store release.

**3. The count goes up, never down.** The app has no roster of who is present —
only a list of who joined. Show presence, never absence. Never name someone who
hasn't put their phone down. A screen that does is both impossible to build
honestly and the exact nagging instrument this product replaces.

**4. Sensors may only ever offer.** Face-down detection, proximity, motion
history — all of it proposes, a human confirms. A false negative (telling
someone they weren't there when they obviously were) is the worst failure this
product can have and is unrecoverable tonally.

**5. Zero required setup.** Never design a feature as "the user must configure
this first". Default it. The only optional setup in the product is screen 20,
it appears after five evenings, and declining it costs nothing.

**6. Apply the knowledge test to every string you write.** *What does the app
actually know, and when did it learn it?* This caught three real bugs during
design: a home screen implying it knew your location, a ceremony screen naming
people who hadn't acted, and a roster of names nobody had entered.

**7. Never gate the ritual on a sensor, a permission, or a network call.**
A session counts whether the phone is face down, in a pocket, or face up and
ignored; whether the place is named or "Somewhere"; whether anyone else joined.

---

## The voice

Caregiver. Warm, quiet confidence — at home on a nice kitchen appliance, not a
phone app that escaped onto hardware. Never a raw stat with no warmth, never
exclamation-point cheeriness, never guilt.

| On-brand | Off-brand |
|---|---|
| "Docked. See you in a bit." | "Session started! 🎉" |
| "Three of you so far." | "Sam and Ellie haven't joined yet!" |
| "That rhythm ended. Yesterday still counts." | "You broke your streak." |
| "We closed this one for you. It still counts." | "Your session ran 9 hours!" |
| "Nothing here yet." | "Let's get started! Complete these 3 steps." |

Never show what was missed — notifications, messages — only what was reclaimed.
Never compare people or households against each other.

---

## Layout

```
VISION.md  BRIEF.md  CLAUDE.md
docs/          APP-SPEC.md, SCHEMA-REVIEW.md
copy/          strings.json — every user-facing string
supabase/      migrations/ (applied, tested) and tests/
prototype/     ceremony.html — the web rehearsal of the five-phone moment
ReclaimKit/    shared Swift package: models, data, ceremony, copy, design
Reclaim/       the app target
ReclaimWidgets/ Live Activity, widget, Control Center control
project.yml    XcodeGen manifest — the project file is generated, not committed
```

---

## Building

The Xcode project is **generated**. `Reclaim.xcodeproj` is not in the repo.

```sh
brew install xcodegen      # once
xcodegen generate          # after any change to project.yml or a new file
open Reclaim.xcodeproj
```

Adding a Swift file needs no project edit — XcodeGen globs the directories.
Adding a target, capability or dependency means editing `project.yml` and
regenerating.

**Configuration** lives in `Config/Secrets.xcconfig`, which is gitignored.
Copy `Config/Secrets.example.xcconfig` and fill it in. The Supabase
publishable key is designed to sit in client code and is protected by RLS, but
it still doesn't belong in git.

## The database

```sh
supabase/tests/run.sh      # 16 assertions against a scratch Postgres
```

Needs a local Postgres reachable via `PGHOST`/`PGPORT`/`PGUSER`. The harness
stubs `auth.users` and `auth.uid()` so the migrations run on bare Postgres.
**Never apply `supabase/tests/00_local_auth_stub.sql` to a real project.**

Migrations are applied to the hosted project in order. Two things to remember
when adding one:

- A new table in `public` arrives with Supabase's default `GRANT ALL` to `anon`
  and `authenticated`. Revoke it, then grant deliberately. `0002` does this and
  sets default privileges so it shouldn't recur — verify anyway.
- A function clients call needs a thin wrapper in `public` (see `0005`), because
  PostgREST only serves exposed schemas and `app` is not one.

**Test SQL by running it.** Five of the fourteen findings in the schema review
were invisible on reading and obvious on executing — three locally, two only
against hosted Supabase.

## Swift conventions

- iOS 17 minimum. `@Observable`, not `ObservableObject`.
- One `AppState` on the environment. No Composable Architecture, no DI
  container, no Redux. At 21 screens they are all overhead. Resist.
- `supabase-swift` is the only dependency. Keep it that way.
- Colors and type come from `ReclaimKit/Design`. No literal colors in views.
- Every screen builds in an Xcode preview against `PreviewRepository` with no
  network.
- Screens are named for the canvas (`HomeView` is screen 2). The spec has the
  full mapping.

## Scope

**Out until explicitly asked for:** the BLE/NFC puck, geofencing, Android,
office/B2B mode, parent mode, payments of any kind. The app is free; the puck
is the business.
