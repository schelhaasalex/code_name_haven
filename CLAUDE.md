# Working in this repository

Reclaim — a phone-free ritual app for iOS. You set your phone down, the people
around you do the same, and the place you did it in slowly becomes something.

> **"Reclaim" is a working name.** The business name isn't settled, and there
> is no real domain yet. Keep both out of anything that's hard to change: a
> person sees the name through `APP_DISPLAY_NAME` (project.yml) and `app.name`
> (copy); links go through `LINK_DOMAIN`, for now a Vercel testing address.
> Module and target names (`ReclaimKit`, `Reclaim/`) stay — nobody sees them.

Read `VISION.md` for why, `docs/APP-SPEC.md` for what is built and how, and
`docs/DOCK.md` for the box. `BRIEF.md` is the brief for the first, 21-screen
app; since 2026-11-06 the app is the box's, and where they differ the spec is
current.
`docs/SCHEMA-REVIEW.md` records fourteen bugs found before any of this shipped
and is worth skimming before touching the database.

---

## Rules that are not style preferences

These have all been arrived at the hard way. Breaking one is a bug, not a
matter of taste.

**1. The client never reads another person's rows.** `sessions` and `profiles`
are own-rows-only at the database. Everything crossing a person boundary goes
through an RPC that returns an aggregate. If a view needs someone else's data
and there's no RPC for it, write a new RPC — do not widen a policy. What a box has kept is everyone's evenings added
up, and the promise is that nobody sees how often anyone else wasn't there.
RLS cannot express "aggregate but not enumerable", so this rule is the promise.

**2. No user-facing string is hardcoded.** Everything lives in
`copy/strings.json`, keyed `screen.element`, read through `Copy["home.headline"]`.
The voice is the product's primary asset; it ships as a bundled fallback and is
overridden from Supabase so it can change without an App Store release.

**3. The count goes up, never down.** The app has no roster of who is present —
only a list of who joined. Show presence, never absence. Never name someone who
hasn't put their phone down. A screen that does is both impossible to build
honestly and the exact nagging instrument this product replaces.

**4. The box is the only switch.** Putting your phone in a slot starts the
evening — that is the person deciding, with a drawer around it. Taking it out
ends it, fifteen seconds later. Nothing else starts one: not face-down
detection, not motion history, not proximity, not a button. A sensor that
guesses is how a product tells someone they weren't there when they were.

**5. Zero required setup.** Never design a feature as "the user must configure
this first". Default it. The only setup in the product is pairing with the
box, once — a tap on its tag or a scan of its code.

**6. Apply the knowledge test to every string you write.** *What does the app
actually know, and when did it learn it?* This caught three real bugs during
design: a home screen implying it knew your location, a ceremony screen naming
people who hadn't acted, and a roster of names nobody had entered.

**7. Never gate the evening on a network call or a permission prompt.**
The box decides; the server is told after. An evening counts whether or not
the network was there when the phone went in, and whether anyone else joined.

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
docs/          APP-SPEC.md, SCHEMA-REVIEW.md, STYLE.md, DOCK.md (the box)
copy/          strings.json — every user-facing string
supabase/      migrations/ (applied, tested), functions/ (Edge Functions) and tests/
scripts/       shape.sh — the style rules, as a check rather than a hope
               generate.sh — the project, with a build number nobody has to remember
               dock-tags.sh — a new box's four slot links and its printed code
prototype/     splash.html — the three splash screens, side by side
firmware/      box/box.ino — the box's Bluetooth radio and slot sensors (ESP32)
ReclaimKit/    shared Swift package: models, data, the box, copy, design
               — and Tests/, which is where anything testable belongs
Reclaim/       the app target
ReclaimWidgets/ the Live Activity, on the lock screen and the wrist
project.yml    XcodeGen manifest — the project file is generated, not committed
```

---

## Branches

```
feature → staging → main
```

`main` is what has shipped. `staging` is what is about to. **Nothing reaches
`main` except a merge from `staging`** — not a feature branch, not a one-line
fix, not the exception that seemed small at the time.

- Branch off `staging`. Open the pull request against `staging`.
- Promoting is its own pull request, `staging` → `main`, and it is where the
  release note gets written.
- `.github/workflows/branch-flow.yml` fails any pull request into `main` whose
  source branch isn't `staging`.
- `.githooks/pre-push` refuses a direct push to `main` from this clone. Turn it
  on once, per clone:

```sh
git config core.hooksPath .githooks
```

Neither is a lock. A workflow can fail a pull request but cannot stop a push;
a hook can be skipped with `--no-verify` and never runs for anything done in
the browser. Branch protection is the real thing and needs GitHub Pro on a
private repository — until then, these two catch the accident, not the
intent.

If `main` ever needs something `staging` hasn't got, the answer is to put it on
`staging` and promote — not to open a shortcut that then exists forever.

## Building

The Xcode project is **generated**. `Reclaim.xcodeproj` is not in the repo.

```sh
brew install xcodegen      # once
scripts/generate.sh        # after pulling, changing project.yml, or adding a file
open Reclaim.xcodeproj
```

Adding a Swift file needs no project edit — XcodeGen globs the directories.

`scripts/generate.sh` is `xcodegen generate` with the build number written
first, as the number of commits behind `HEAD`, into `Config/Build.xcconfig`
(gitignored). App Store Connect refuses an upload whose build number it has
already seen, and bumping it by hand is a step only ever noticed by being
forgotten — at the end of an archive, after the wait. **The number must not go
back into `project.yml`**: a build setting there wins over an xcconfig, so it
would override the generated one silently. `scripts/shape.sh` checks that.

Two schemes: **Reclaim** is the real app against Supabase. **Reclaim (Sample
data)** runs the whole app against the canvas household (`PreviewRepository`),
in memory, with its box, no network — debug builds only. It's how to see the
app without a box; `xcrun simctl openurl booted reclaim://d/any/1` puts a phone
in it.
Adding a target, capability or dependency means editing `project.yml` and
regenerating.

**Configuration** lives in `Config/Base.xcconfig`, which both targets read. It
includes `Secrets.xcconfig` — gitignored, copy `Config/Secrets.example.xcconfig`
and fill it in — and `Build.xcconfig`, which `scripts/generate.sh` writes. The Supabase
publishable key is designed to sit in client code and is protected by RLS, but
it still doesn't belong in git.

## The database

```sh
supabase/tests/run.sh      # 206 assertions, in 34 blocks, on a scratch Postgres
node --test supabase/tests/apns.test.ts   # the Live Activity push, signed and checked offline
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
  container, no Redux. At a handful of screens they are all overhead. Resist.
- `supabase-swift` is the only dependency. Keep it that way.
- Colors and type come from `ReclaimKit/Design`. No literal colors in views.
- Every screen builds in an Xcode preview against `PreviewRepository` with no
  network.
- Screens are named for the canvas (`HomeView` is screen 2). The spec has the
  full mapping.
- One view per file, components take data rather than `AppState`, and logic
  worth testing moves to `ReclaimKit` as functions over plain values.
  `docs/STYLE.md` is the long version.

```sh
xcodebuild test -scheme ReclaimKit -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Shape

The rules above are checked mechanically, because the alternative was tried:
they were written down, and the same week, the file documenting them had six
components in it and the file beside it had four screens.

```sh
scripts/shape.sh      # about a second, no toolchain, no network
```

| Checked | Because |
|---|---|
| No Swift file over 220 lines | A file nobody re-reads before adding to it is how it got long |
| One view per file, named for the file | "Unless they're variants of one idea" is not a rule anyone holds |
| `Reclaim/Components/` never mentions `AppState` | It's what keeps a component previewable and behaviour-free |
| No `Text("…")` outside a `#Preview` | Rule 2 — a baked string can't be changed without a release |
| No literal colours outside `Design/` | A hex in a view drifts from the one beside it |
| Every view has a `#Preview` | Screen 13 is unreachable at runtime without an evening the server closed |
| Every `t("key")` is in `strings.json` | A missing key is `⟨key⟩` in dev and empty to a person |
| The bundled `strings.json` matches `copy/` | Same file, two places; keeping them equal is the job |
| `LaunchBone` matches `Palette.bone` | UIKit reads `Info.plist` before any Swift runs, so the launch colour genuinely is the same fact twice |
| Links use `LINK_DOMAIN` | There's no real domain yet; a host written into Swift is one the rename misses |
| A phone in the box keeps listening | Without `bluetooth-central` the box's news never reaches a phone that's locked — and nothing says so |
| Every sheet has something that opens it | Screen 17's "Name them" was a word printed on a card: the sheet was wired, nothing set the flag, and it built and previewed fine |
| The build number is not written into the project | A setting in `project.yml` beats the xcconfig it comes from, so every upload after the first would carry the same number — refused at the end of an archive, not the start |
| The box's lights can be found | iOS won't browse for a Bonjour service missing from `NSBonjourServices`, and says nothing — the box just never lights |
| A Live Activity can be started by push | Without `aps-environment`, iOS never hands out a push-to-start token, and an evening the box started shows nothing on the lock screen |
| The ring charges the same on the phone and the server | The phone steps the ring while it's awake and the server after; two lists of steps that differ make it jump back a segment |
| Only the box starts an evening | Rule 4. A button, face-down, a motion guess, a nearby phone and Siri were each one call to `setItDown` from somewhere new |
| Every link the app makes opens it | The site claims every path but the home page. Phones cache `apple-app-site-association` for days, apart from the app, and a path added later (`/d/`, the slot links' first home) opened Safari until that cache refreshed |

It runs in CI on every pull request, and from a `Stop` hook in
`.claude/settings.json` — a session here cannot end on a repo that breaks it.

**A rule added to `docs/STYLE.md` without a check in `scripts/shape.sh` is a
suggestion.** Write the check, and make it fail before you make it pass.

## Scope

**In:** the box — a drawer with four charging slots, an NFC tag and a light on
the outside for each (in scope since 2026-10-22). It ships with the app, so
putting a phone in it has to be enough. `docs/DOCK.md` has how it works.

**Out** (since 2026-11-06): every way of starting an
evening but the box — face-down, retroactive credit, phone-to-phone proximity,
Siri and Control Centre, cards and invites.

**Out until explicitly asked for:** geofencing,
Android, office/B2B mode, parent mode, payments of any kind. The app is free;
the puck is the business.
