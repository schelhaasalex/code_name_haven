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

---

# Puck study

`puck.html` is the object rather than the app: a real-time 3D study of where
the phones go, and of what would make it worth $200–500.

| Shape | What it is |
|---|---|
| **Household** | Six phones. One solid piece, machined wood or bead-blasted aluminium, with a single hairline seam all the way round. The hinge is hidden inside the back: push the front edge and the lid lifts, and it closes slowly on its own. A pressed-leather insert holds each phone screen up in its own well. Optional leather panel set flush into the lid; fine-bevel or soft edges. |
| **Bedside** | The same object for one phone. Twelve pinholes in the front fill over three hours. |
| **Tray** | Kept for comparison only: phones face down can't charge. |

Wireless charging is through the back of the phone, so phones lie screen up
and the solid lid is what hides the screens. Light comes through pinholes,
invisible until lit, and as a hairline at the seam. No hardware shows on the
outside.

**See inside** separates the box into its layers with callouts: plinth, driver
board, body, coils over ferrite, magnet rings, the leather insert, phones,
lid, plus the hidden hinge, the vents and the single USB-C cable. It is a proposal, not an engineered design.

**Try it** lets you set phones down, pick them up (the lock screen shows the
Live Activity), open and close the lid, and end the evening. **An evening**
plays a scripted night from 6:30 to 11:00. Finishes and light colours switch
live.

It holds to the product rules: lifting a phone never dims its light, an empty
bay is just space rather than someone missing, the lid has no latch, and
nothing ever knows a name. Open it straight from disk; three.js loads from
jsDelivr, so it needs a network connection.
