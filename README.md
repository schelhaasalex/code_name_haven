# Reclaim

**The people in the room matter more than the ones in your pocket.**

> "Reclaim" is a working name — the business name isn't settled, and there's no
> real domain yet. See the note at the top of [CLAUDE.md](CLAUDE.md).

A box with four charging slots, and an iPhone app that belongs to it. Put your
phone in a slot and your day's time begins; take it out and it ends, five
seconds later. Everyone whose phone is in the same box is in it together, and
the box keeps everyone's time, added up. Nothing blocks an app, nothing locks,
and nobody is shown who wasn't there. [VISION.md](VISION.md) says why.

The app is free. The box is the business.

## Where to read

| | |
|---|---|
| [CLAUDE.md](CLAUDE.md) | The rules — the ones that aren't style preferences — the voice, the layout, building, branches |
| [docs/APP-SPEC.md](docs/APP-SPEC.md) | What the app is and how it's built, screen by screen; shipping a build |
| [docs/DOCK.md](docs/DOCK.md) | The box: its slots, its radio, the protocol, the factory station |
| [docs/STYLE.md](docs/STYLE.md) | How the code is shaped, and what's worth testing |
| [docs/SCHEMA-REVIEW.md](docs/SCHEMA-REVIEW.md) | Fourteen bugs found before any of it shipped — read before touching the database |
| [BRIEF.md](BRIEF.md) | The first brief. Historical: where it and the spec differ, the spec is current |

## Running it

```sh
brew install xcodegen
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # add the Supabase publishable key
git config core.hooksPath .githooks                           # once per clone
scripts/generate.sh
open Reclaim.xcodeproj
```

The project file is generated, not committed: run `scripts/generate.sh` after
pulling or adding a file. The **Reclaim (Sample data)** scheme runs the whole
app in memory with a box of its own and no network — the way to see it without
the hardware.

## Checking it

```sh
scripts/shape.sh                 # the rules, as a check — about a second
xcodebuild test -scheme ReclaimKit -destination 'platform=iOS Simulator,name=iPhone 17'
supabase/tests/run.sh            # the database, on a scratch Postgres
```

`scripts/shape.sh` runs in CI on every pull request and from a hook when a
Claude Code session here ends.

## Branches

`feature → staging → main`. Branch off `staging` and merge back into it;
nothing reaches `main` except a merge from `staging`. CLAUDE.md has the rest.
