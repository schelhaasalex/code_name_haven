# The simpler app

Decided 2026-11-06. This is the plan for getting from the 21-screen app to the
one below; it is deleted once the spec describes what's built.

## The product, in one paragraph

You put your phone in the box. That starts your evening — nothing else does.
Everyone whose phone is in the same box is in the same evening, and the ring on
the lock screen and the wrist fills over an hour and a half, with a light for
each of you. Take your phone out and, fifteen seconds later, your evening is
over. Every evening adds to the box, and the box keeps all of it.

## Decisions

1. **The box is the only switch.** A slot filling starts the evening (the phone
   checks it was the one that just started charging, with the box beside it).
   The phone leaving charging ends it after 15 seconds — long enough to put it
   back if it slipped, not long enough to check a message. No face-down
   detection, no "you were away 36 minutes", no Siri, no Control Centre
   button, no phone-to-phone joining.
2. **Together means the same box at the same time.** The box's place has one
   open gathering; every phone docked in it joins that one (`start_or_join`
   already works this way). No invites, no cards, no ceremony.
3. **The incentive is the ring, and the box that keeps everything.** Per
   evening: the ring (`EveningCharge`, built). Over time: a total that only
   grows — this week, and all of it — and the place stages that already exist
   (`app.place_stage`: a regular table → a landmark). The total belongs to the
   box, not to anyone's account, so it is never lost and never compares people.
4. **A place is a box.** Its name is the box's name. No naming flow, no merging,
   no "Somewhere".
5. **Pairing is the only setup, once.** Tap the box's NFC tag, or scan its QR
   code — the same link, two ways to read it (the camera opens a universal link
   like the tag does). That teaches the phone which box is its own and asks for
   Bluetooth there, where the question makes sense. A second person does the
   same.
6. **Accounts are made silently.** Supabase anonymous sign-in on first launch;
   no Welcome, no Sign in with Apple. Because the total lives with the box,
   reinstalling loses only your own history.

## Rules that change

- **Rule 4** becomes *The box is the only switch*: in starts, out ends after
  15 seconds; no sensor or button starts an evening.
- **Rule 5**: the only setup is pairing with the box, once.
- **Rule 7**: never gate the evening on a network call or a permission prompt —
  the box decides, the server is told after.
- **Scope**: phone-to-phone proximity is out.

## What a person sees

| Screen | |
|---|---|
| Pair | "Tap the tag or scan the code on your box." |
| Home | The box's name and stage; tonight's ring if it's on; this week; all of it |
| Evening | The ring, the lights, since when — the Live Activity is the main surface |
| Settings | Rename the box, leave it |
| Closed for you | Kept: an evening the server had to close still counts |

## What goes

Retroactive credit (screen 18, `RetroactiveCredit`, `StationaryRuns`); face-down
(`FaceDownSensor`, `Sensation`); nearby (`NearbyBeacon`, `NearbyScanner`,
`AppState+Nearby`); intents and one-tap (`SessionIntents`, `DockIntents`,
`ReclaimShortcuts`, `OneTapView`, the Control Centre control); the ceremony and
invites (`Ceremony*`, `Invitation`, `JoinInviteView`, `InviteSheet`,
`CountUpView`); cards (`CardView`, `ScanCardView`, `CardCamera`, `QRCode`);
places as their own thing (`PlacesView`, `NamingView`, `WhereSheet`,
`MergeView`, `UsualPlace`); rhythms and nudges (`RhythmView`,
`RhythmEndedView`, `NudgePlan`, `AppState+Nudge`); Welcome and Sign in with
Apple. `prototype/ceremony.html`.

The database keeps its tables until the new app has shipped; a later migration
drops what nothing calls.

## Order of work — one pull request each

1. **This plan**, and the rules in CLAUDE.md.
2. **Out ends it.** Slot empties → each docked phone wakes, waits 15 s, and
   ends its own evening if it isn't charging. Testable on the box today.
3. **Delete** the sensors, retroactive credit, nearby, intents, ceremony,
   invites and cards.
4. **Places are boxes; Home** becomes the box, tonight, this week, all of it.
5. **Pairing** by tag or QR; anonymous accounts.
6. **Clean up** the spec, `shape.sh` checks for deleted things, CLAUDE.md.

## Still open

- **Overnight.** A phone left in the box to charge overnight is an evening
  until the server's 3-hour cap closes it. Is three hours right, or should an
  evening stop at, say, midnight?
- **An End button.** With out-ends-it there's no need for one; keep it on the
  lock screen for the phone that stays in overnight, or drop it?
