# Reclaim — Project Brief (v2, software-only)

A phone-free ritual app. You set your phone down, the people around you do
the same, and the place you did it in slowly becomes something. **V1 has no
hardware.** The BLE/NFC puck is v2 and out of scope until asked for.

Screens: see the canvas at `https://claude.ai/artifact/RuTNpxy63bmnsAGC6cXLjL`
(21 screens plus an IA map). Where this document and the screens disagree,
the screens are newer.

---

## Three rules that override normal instincts

**1. Zero required setup.** Never design a feature as "the user must
configure this first." Default it. The only optional setup in the entire
product is screen 20, it appears after five evenings, and declining it costs
nothing.

**2. Brand voice test.** Would this feel at home on a nice kitchen
appliance, or like a phone app that escaped onto hardware? The archetype is
Caregiver — warm, quiet confidence. Not Rebel (Brick's edgy flex), not a
guilt-driven wellness app. Never a raw stat with no warmth, never
exclamation-point cheeriness.

**3. The knowledge test.** For every user-facing string: *what does the app
actually know, and when did it learn it?* This caught two real bugs during
design — a home screen that implied it knew your location, and a ceremony
screen that named the people who hadn't complied yet. Both were impossible
and both were off-brand. Apply it to every sentence.

| Moment | On-brand | Off-brand |
|---|---|---|
| Session start | "Docked. See you in a bit." | "Session started! 🎉" |
| Others joining | "Three of you so far." | "Sam and Ellie haven't joined yet!" |
| Session end | "2h 14m reclaimed." | "Great job! You earned 134 points!" |
| Forgot to end | "We closed this one for you. It still counts." | "Your session ran 9 hours!" |
| Retroactive offer | "You were away for an hour and forty. Count it?" | "1h40m of inactivity detected." |
| Rhythm ends | "That rhythm ended. Yesterday still counts." | "You broke your streak. Start over." |
| A place matures | "A reclaim house since March." | "LEVEL 3 UNLOCKED" |
| Day one | "Nothing here yet." | "Let's get started! Complete these 3 steps." |

---

## Vision & metrics

**Pitch: we help you connect intentionally.** Not "we're not watching you" —
privacy is table stakes here, not the product. The product is the people in
the room.

**Northstar: co-present evenings per group per week.** Not hours. A
household where four people dock separately on four floors scores identically
to one that ate dinner together, and only one of those is the product.
Overlapping sessions are the unit of value.

**Operating metric: % of days with at least one qualifying session, per
person.** Consistency over volume. No feature may let one long session
outweigh showing up regularly.

Hours reclaimed is a supporting number, not the headline.

---

## Tech stack

- **Native Swift / SwiftUI. iOS only.** Not React Native, not Expo.
- **Minimum iOS 17**, forced by the product: an interactive End button on a
  Live Activity requires App Intents in widgets (iOS 17+). Before that a Live
  Activity is display-only and ending means unlocking the phone you just put
  down.
- **Xcode project with a Widget Extension from day one** (app target, widget
  target, shared models in a local Swift package). Retrofitting that split
  later is painful; doing it on an empty repo is free.
- **Supabase** — Postgres, Auth, Realtime, RLS, via `supabase-swift`.
- **State:** SwiftUI `@Observable` plus a thin repository layer over the
  Supabase client. At ~20 screens this app does not need Composable
  Architecture or anything like it. Resist.
- **Notifications:** `UserNotifications`, scheduled locally. **No remote
  push.** No APNs certificates, no push tokens, no server-side send. Every
  notification in the product is schedulable on-device.
- **Auth:** Sign in with Apple only. No passwords anywhere.
- **Distribution:** TestFlight (needs a paid Apple Developer account — start
  that early, it gates the first real test).
- **Copy lives in Supabase** with a bundled fallback, so user-facing strings
  can change without an App Store release. The voice is the primary asset;
  don't lock it in a binary.

---

## What the app knows

This section exists because it is the most common source of design bugs.

**A place attaches four ways, none of which is location:**
1. Tap the NFC tag on the card that lives there.
2. Scan the QR on the same card.
3. Join someone else's session — the place comes from theirs.
4. Name it afterwards.

A session with **no place is a first-class object**, labelled "Somewhere",
and counts identically. Nothing downstream may assume a place exists.

**The app never requests location.** Not because privacy is the pitch, but
because the cheaper mechanisms cover the real cases and an Always-location
prompt during onboarding is a bad trade. If arrival detection is ever wanted,
geofencing is the v1.1 answer: region monitoring runs on-device and reports
"entered region 3", not coordinates — but it may only ever *offer*, never
auto-start. A session that begins by itself is not a ritual anyone performed.

**The app has no roster of who is present.** It knows who joined. So the
ceremony counts **up, never down** — presence, never absence. Never name
someone who hasn't put their phone down.

**Face-down detection is ceremony, not evidence.** A phone in a pocket is not
face down and its owner is entirely present. Never gate anything on it. Raw
accelerometer streaming is restricted in the background anyway; the reliable
window is while the app is foregrounded, which is exactly when the gesture
happens.

**Names:** every person's display name is **self-chosen**, seeded from Apple
on first sign-in, editable in settings. That is how someone becomes "Dad" —
he picked it. There are no per-viewer nicknames and no Contacts access.
Apple hands over the name exactly once, on first authorization ever, so
capture it then or lose it permanently; fall back to an empty field and ask.

---

## Data model (Supabase / Postgres)

`profiles` — `id` (fk auth.users), `display_name`, `nudge_enabled`,
`nudge_hour`, `created_at`

`places` — `id`, `name` (nullable), `handle` (unique word pair, printed on the
card, display only), `join_secret` (long random, lives in the tag and QR),
`created_by`, `site_id` (nullable — see Hierarchy), `created_at`

`place_people` — `place_id`, `profile_id`, `first_seen_at`. Written the first
time someone docks there. This is what RLS keys off and what screen 17 lists.

`gatherings` — `id`, `place_id` (nullable), `started_by`, `started_at`,
`ended_at`. Every session belongs to one; a solo session is a gathering of
one. This is what "five of you" counts.

`sessions` — `id`, `profile_id`, `gathering_id`, `place_id` (nullable),
`started_at`, `ended_at` (nullable while live), `duration_minutes`,
`local_date` (the user's local calendar date at start — computed at write
time; this is what streak maths uses), `qualifying` (bool, snapshotted),
`auto_closed` (bool), `retroactive` (bool), `source`
(`app|tag|control|siri|shortcut|retroactive`), `puck_id` (nullable, always
null in v1)

`rhythms` (cached, fully recomputable from sessions) — `profile_id`,
`state` (`in_rhythm|between`), `current_run_days`, `longest_run_days`,
`last_qualifying_date`, `rest_day_available` (bool)

**Deleted from v1 relative to the original brief:** `households`,
`household_members`, `reward_tiers`, `redemptions`, `invites`, `streaks`,
and every points column. Points and rewards are gone entirely — a place
accrues character, not currency. Inviting a friend is a share-sheet link, not
a table.

**Constants, not configuration.** Qualifying minimum (15 min), auto-close
ceiling (3 hours), rest-day refresh (weekly). Screen 16 states these as facts
rather than offering them as dials. There is no settings table.

**Row Level Security.** Everything scopes through `place_people` for the
calling user. Write the membership check as a `SECURITY DEFINER` function
returning the caller's place ids and have every policy call it — a policy on
`place_people` that itself queries `place_people` causes infinite recursion,
which is the classic footgun with exactly this shape.

**Hierarchy.** Don't build a tree. Sessions always happen at a leaf, so a
parent is only ever a *reporting* concern and can be added later without
touching the session model. When it's needed: one nullable `site_id`, **depth
one**, rooms belong to a site and sites never belong to sites. Arbitrary
depth means recursive CTEs and genuinely nasty RLS. The likely failure is
fragmentation (four rooms, eight evenings each, every place permanently
"new here") and the fix for that is **merge**, not nesting.

**V2 note.** A `pucks` table and `sessions.puck_id` going non-null are the
only schema changes hardware needs. Nothing above should change shape.

---

## The mechanics

**Qualifying.** A session counts past 15 minutes. `qualifying` is snapshotted
so changing the threshold never rewrites history.

**Auto-close.** If nobody ends it, close at 3 hours and **credit at the cap**,
not at the nine hours the phone actually sat there. Otherwise the cheapest
strategy in the product is to start a session and never end it, and the
headline number becomes garbage. The only correction offered to the user is
downward ("that wasn't a real one — remove it").

**Retroactive sessions.** Query `CMMotionActivityManager` history when the
user next opens the app and offer to credit time already passed. No
background task, no notification — a card waiting on Home. This is what makes
solo use viable without anyone remembering to start anything. Verify the
history window against current Apple docs before planning around it.

**Rhythms, not streaks.** A person is `in_rhythm` or `between`. Binary state,
not a rank. One rest day, refreshed weekly, spent automatically. Falling out
is never punitive: days already banked never disappear and one evening puts
you back. No tier, no decay, nothing to lose by not opening the app.

**Place stages.** `new here → a regular table → a reclaim house → a
landmark`, derived from the evening count. **They only ever move forward.**
A place cannot be demoted, isn't a person so ranking it shames nobody, and it
belongs to everyone who's been there. It also rewards hosting and inviting,
which is the cold-start problem.

**Place names and ownership.** A place has **two identifiers and they do
different jobs.** The `name` is human and meaningful ("The Kitchen Table").
The `handle` is a generated word pair ("Amber Otter") printed on the card —
sayable down a phone, easy to tell two cards apart, and stable forever.
Renaming therefore never invalidates a card, a session or any history.

Do **not** generate a whimsical name. Colour-plus-animal is the wrong
archetype (Jester, not Caregiver) and it fights the point of screen 9 —
"Amber Otter has been a reclaim house since March" is absurd where "The
Kitchen Table" is not. Defaults stick, so a cute one would quietly displace
the meaningful one. Generated names are right for the handle and wrong for
the name.

**The handle is not a credential.** The join secret is a long random value
inside the NFC tag and the QR; typing "Amber Toucan" gets you nothing. If the
sayable identifier were also sufficient to join, a small dictionary would be
brute-forceable and "being in the room" would stop being the access control.
Rate-limit resolution of the secret regardless.

A name is set one of three ways, all optional and none blocking: you name it
when you print its card, you name a "Somewhere" bucket afterwards and its
sessions attach to the new place, or you never name it at all. Offer around
six one-tap suggestions when naming rather than an empty text field — nothing
can be inferred, but a blank box is the worst moment in any flow, and the
list genuinely covers most cases. Never frame an unnamed place as a
deficiency: "four evenings, somewhere — they count the same", not "you never
named these".

Only `created_by` can rename. Don't build more permission than that: if you
think someone's place is misnamed you are sitting in the room with them, and
not every disagreement needs a UI. Renaming relabels all history and never
resets the stage or the evening count; it should offer a reprint of the card,
not force one. Merging asks which name survives. If the owner deletes their
account the place survives and ownership falls to whoever has the most
evenings there. **No per-viewer names** — it breaks shared language and
dilutes the place's character, which is the entire point of screen 9.

**Visibility.** People you dock with see live presence and group totals. They
never see your per-day history, your rhythm, or how often you weren't there.
This is not a privacy nicety — it is what makes the product survivable with
teenagers, who will not use an app their parents audit them with.

**Notifications.** At most one per day, at a fixed hour, never during a
session, and never a reminder to *end* one. A buzz telling you to pick up
your phone is the app becoming the problem.

---

## Build order — separate sessions, not one request

1. **Scaffold + schema.** Xcode project with widget extension, Supabase
   tables, RLS with the security-definer membership function, Sign in with
   Apple, display-name capture on first authorization.
2. **The session loop.** Start, live timer, end, qualifying logic, auto-close
   at the cap, `local_date` handling. Everything depends on this; get it
   solid before building on top.
3. **The ceremony.** Supabase Realtime broadcast so one person's tap makes
   every phone in the gathering respond at the same instant, plus face-down
   confirmation via the accelerometer. **Build this before any radio work** —
   if the moment doesn't land over a websocket it won't land over BLE either,
   and this version costs almost nothing to test.
4. **Live Activity + entry points.** Lock-screen timer with a working End
   button, NFC tag reading, a Control Centre control, App Shortcuts for Siri.
   This is the work that makes the app one you never open.
5. **Places.** Codes, cards, the stage ladder, the places list, merge.
6. **Rhythms.** The state machine, the rest day, the grid.
7. **Retroactive credit.** Motion history query and the "Count that?" card.

**Out of scope until explicitly requested:** all BLE/NFC *puck* hardware,
geofencing, Android, B2B/office mode, parent mode, payments of any kind.

---

## Decisions already made

Listed so a build session doesn't silently re-litigate them.

- **The app is free.** The puck is the business. No StoreKit, no paywall, no
  billing columns. (Physical goods can't be sold through IAP anyway, so
  hardware revenue never touches Apple's cut — that's an argument *for* this
  model, not a problem.)
- **No tab bar.** Home is the root; places, rhythm and settings are reached
  from the moment that warrants them. A tab bar advertises that there's
  something to browse, which is the one thing this app shouldn't say.
- **Places are claimed by whoever docks there first.** Anyone holding the
  card can join — being in the room is the access control.
- **The honor system stands.** Co-presence is the verification: five people
  independently declaring the same session is mutual attestation, and you
  can't fake four friends. No blocking, no Screen Time / Family Controls
  shielding — that's the restriction product this one is defined against.
- **Solo has to be good; group has to be magic.** Solo carries v1 because
  the network doesn't exist yet. Never design the single-person case as a
  degraded version of the group one.
- **Sensors may only ever offer, never refuse.** A false negative — the app
  telling someone they weren't there when they obviously were — is the worst
  failure this product can have, and it's unrecoverable tonally.
- **Account deletion must be in-app** (App Store guideline 5.1.1(v)).
- **Don't key anything on Apple's user identifier.** Use the Supabase user id
  and let Apple be one linked identity, or adding a second provider later
  becomes a migration.

---

## Open questions

- **What does a teenager want from this?** Privacy makes it safe to use; it
  is not a reason to open it. The likeliest answer is that their friends are
  already in it, which makes the friend-group loop (screens 4 and 5) the
  thing to get right — not the rhythm screen.
- **The name.** "Reclaim" is good and it's what everything is written
  against. Reclaim.ai exists in the calendar space. Worth a trademark check
  before it's on a screen.
- **Does the ceremony actually feel like anything?** Unanswerable from
  mockups. Five people, one real table, the Realtime prototype from step 3.
  That test comes before any further design work.
