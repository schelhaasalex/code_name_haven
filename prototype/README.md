# Ceremony prototype

A working rehearsal of the five-phone moment — the one thing in Reclaim that
no mockup can test. Published at
`https://claude.ai/artifact/B3thhUz4V34WLEumG2e2AQ`; this is its source.

Open it, type a name, **Sit down**, then **Set it down**. Every phone in the
room answers at once: the screen drops to near-black, a two-note chime plays,
a ring opens, and the count resolves. Then face-down sensing via the
accelerometer, the timer, and the summary.

**Rehearse it on your own** runs the whole sequence with three simulated
people, so a single device can tell you whether the timing lands.

## Two things to know

It uses the Claude artifact **room** capability for cross-device sync, which
only connects viewers inside the author's Claude organization. Good for your
own devices; not a five-friend dinner. To run that test, swap the `room` calls
for a Supabase Realtime channel and host it anywhere static — same page
otherwise, and then anyone with the link can join from any phone, iOS or
Android.

There is **no haptic on iOS Safari** (no Vibration API in WebKit), so the web
version has sound and a screen change where the native app will have a buzz.

## Why it's in the repo

Timing is the part of the ceremony that has to be *felt* rather than
specified. Whatever the dinner test settles here — the gap between the chime
and the ring, how fast "Turn your phone over" arrives — is the reference for
`CeremonyEngine` in `docs/APP-SPEC.md`. Port the answer; don't re-derive it.
