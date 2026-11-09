# Polish

Written 2026-11-09, after the five bugs in the first pass were fixed. This is
the design for the rest; nothing here is built yet. Delete it once the spec
describes what's built, as `SIMPLER.md` was.

## The principle

The app was cut down to the box on 2026-11-06. Polish has to keep it there:
**each change below either takes something away or makes two things into one.**
Where the first pass suggested adding something, it is kept only if it
removes a moment of doubt and puts no new control on screen. What was
dropped, and why, is at the end.

---

## 0 — Splash

**Only on a cold launch to Home.** A launch from a tag, the Camera app, or
with an evening already running goes straight to what's underneath, on the
same bone ground. Someone holding a phone beside the box is in the middle of
something; two seconds of logo is in the way.

No copy changes.

## 2 and 2a — Home, with a box or without

**One Home, not two.** Today "Meet your box" replaces the sky, so forgetting
your last box hides days you still have. Instead the sky is always drawn when
there are days to draw. Only the line under it changes:

| State | Headline | Under it |
|---|---|---|
| No box, no days | *Meet your box.* + the pairing line + **Scan the card** | (no sky) |
| No box, some days | *Meet your box.* + **Scan the card** | the sky, the days line |
| A box, today waiting | *Put your phone in The Harbor.* | the days line |
| A box, today counted | *Today counts.* | the days line |

**The box is named once.** It is in the top-left eyebrow *and* the headline.
Drop the eyebrow. The top of Home is then just the settings mark. The name
appears while it's useful, in the instruction, and goes with it once today
counts.

**Zero days says nothing.** The line under the headline is currently
`home.body` ("Put your phone in the box…"), which repeats the headline. At
zero there's no line. Delete `home.body`.

**The settings mark is a gear.** `slider.horizontal.3` reads as filters and
dials, and the app has neither. `gearshape`, at the same weight as now.

**The part of the day keeps time.** "Tuesday afternoon" becomes "Tuesday
evening" at five without the app being reopened (one `TimelineView`, as the
evening screen already has).

## 2b — Scanning the card

**A code that isn't the card gets an answer, in the same line.** After a
couple of seconds of a QR code that isn't the box's, the prompt under the
frame changes from *The card that came with your box.* to *That's a
different code. It's the one on the card that came with your box.* No new control. It goes
back once there's nothing in view.

**Bluetooth off** is done (the first pass's bug 2).

Delete `scan.eyebrow`, which was never shown.

## 6 — In the box

**One shape for the evening, everywhere.** The app, the lock screen and the
wrist each split the headline differently. Now:

- **Headline: where the evening has got to, always.** *See you in a bit.* →
  *Settling in.* → *Today counts.* → *Unwinding.* → *Present.* → *Recharged.*
- **The line under it: who and since when.** *Since 7:27* alone; *Three of
  you · since 7:27* together.

The count still goes up, and on the screen, but it no longer pushes the stage
line out of view. A group never sees *Today counts.* now, and that line is
the reward. This is the wrist's layout already. Lock screen and app adopt it,
and `session.together` / `lockscreen.together` go.

**The countdown is the first frame.** Opened in a hand, the app starts
counting down at once. Check that it never draws the evening's headline for a
frame first. If it does, decide "in a hand, not charging" before the first
render, not after it.

**One haptic, when the countdown starts.** That's the one moment on this
screen with the phone in a hand. Nothing when someone joins: that phone is in
a box, and nobody would feel it.

## 8 — The receipt

**The star lands with a tap you can feel.** One light haptic as today's star
fills. It's the one moment of reward in the app and it's currently silent.

**An unknown box says nothing.** With no place, *At The Landing.* names a box
that doesn't exist. The line is left out. (Same on the lock screen: *Since
7:27*, not *The Landing · since 7:27*.) `box.unnamed` stays only as the
fourth box's default name.

Remove the orphaned comment in `SessionEndView`.

## 13 — We closed this one for you

**A sheet the size of what it says**, in `ConfirmSheet`'s shape, rather than
full height with spacers. And one fewer sentence: the headline takes the
voice table's line whole.

> **Tuesday evening**
> **We closed this one for you. It still counts.**
> Your phone went in at 7:12 and we never heard it come out, so we counted
> three hours and stopped there.
> [ The Harbor · Counted to the cap · 3h ]
> **Fine by me**
> That wasn't a real one — remove it

`autoclosed.counts` goes.

## First launch, offline

**It tries again by itself when the network comes back,** not only when the
app is reopened. The button stays for someone who'd rather tap, and goes
quiet while trying, so a tap with no network doesn't look like nothing
happened.

## 16 — Settings

**Privacy moves into Settings, and its screen goes.** It's two paragraphs
behind a row of their own. They become the last section above the footer,
under *What we can see*. That's one fewer screen, and one fewer place where
"what does this app know" is kept.

**Deleting the account goes home.** After it succeeds, Settings pops back to
Home, now fresh, and says so once in the banner: *Your account has gone.
This phone starts again from here.* Nothing else changes.

**The ring notice listens.** The "ring is turned off" card is checked again
whenever the app comes back to the front, so turning it on in Settings and
returning clears it.

**The version line is legible.** `Palette.muted`, not `hairline`.

## 16a — One box

**Nothing jumps.** When the box's summary arrives late, the stage card fades
in rather than pushing the radio and the name down under someone's thumb.

## 7 — Lock screen, Dynamic Island, Watch

The headline and the line under it as in **6**.

**One mark in the Dynamic Island.** The compact island draws the ring
without its people and puts a bare number beside it. Draw the ring with its
lights, as the lock screen does, and drop the number. Alone, nothing
changes.

## Copy

- Delete: `home.body`, `scan.eyebrow`, `box.kept.label`, `onetap.decline`,
  `autoclosed.counts`, `session.together`, `lockscreen.together`,
  `settings.privacy`.
- Delete the keys that only survive in component previews, for things that
  are out of scope: `home.primary` (Set it down), `session.end` (End),
  `settings.signout`, `settings.nudge.title`, `places.somewhere.*`. Each
  preview uses a real key instead. A preview with an "End" button is how one
  comes back.
- New: `scan.other` (the different-code line), `settings.deleted` (the
  banner after deleting), and the shape `{count} · since {time}` shared by
  lock screen and app (`wrist.together` already says it).

---

## Dropped from the first pass, and why

| Suggested | Dropped because |
|---|---|
| A torch in the scanner | A control for a rare case. Auto-exposure reads a card in a dim kitchen, and the Camera app fallback is already there |
| Naming the box when it's found | `SIMPLER.md`: "No naming flow." It has a name; renaming is Settings |
| A "something's not right" path | `Note`s already tell the pilot what broke, and a form is setup by another name |
| More in the privacy text | Apple ID and deletion are already said where they happen |
| Dots instead of the Island's number | Illegible at 16pt. Dropping the number does it better |
| A haptic when someone joins | The phone is in a box |
| Words vs digits past twelve | That's `Say.number`'s house style, and right |

## Open

1. **Privacy into Settings.** It removes a screen, but the App Store asks for a
   privacy policy link, and the full policy belongs on the site. Inline here,
   plus a link from App Store Connect, is enough?
2. **The stage over the count.** *Three of you so far.* is in the voice table
   as the example of on-brand. It stays, but in the smaller line. Is that the
   right weight for it?
3. **Home without the box's name on top** once today counts. Fine with
   one box; with two, is "which box was I last at" worth the eyebrow?
