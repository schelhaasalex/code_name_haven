# The box

Four slots in a drawer. Each slot has a MagSafe-style charging pad, a sensor,
an NFC tag under where the top of the phone lands, and a light on the outside.
The box has a small Bluetooth radio, and a code printed on it.

Putting your phone in the box **is** the evening starting, and taking it out
is the evening ending — fifteen seconds later (`Box.outGrace`), unless it's
back by then. Nothing else starts or ends one.

## What happens

1. **Meeting it, once.** Point the camera at the box's code, or hold the phone
   to any slot's tag. The app finds or makes the box's place, makes you one of
   its people, asks about Bluetooth, and keeps the dock it's closest to as its
   box. The code starts nothing; a tag is read with the phone going in, so it
   starts the evening too.
2. **In.** A phone lands on a pad. The box lights the slot and tells every
   connected phone. The one that just started charging, with the box right
   beside it, starts its evening — locked, in the background, nobody touching
   anything. The Live Activity arrives by push.
3. **Out.** A slot empties. Fifteen seconds later the phone that still isn't
   charging ends its evening, and its Live Activity goes. Back within the
   fifteen and nothing changed.

A box with no lights, a declined Local Network prompt, or a controller on
another Wi-Fi: the light stays off and the evening counts all the same.

## The box's place

The tags and the code carry one secret: the box's join credential. The box has
no owner until someone reads it. The first phone to read it makes its place,
and every phone after that is one of its people (`dock_place`, migrations 0013
and 0017). The secret is unique in the database, so two phones going in at the
same moment still make one place. Whoever made it can name it, in Settings.

## Building one

**Tags and code.** `scripts/dock-tags.sh` prints four slot links and the box's
code under a fresh secret, and draws the code as `box-code.png` to print and
stick on the box. Write each slot link onto its slot's tag as a URL record (NFC
Tools does this). Use one secret per box, and **never lock the tags**: the
domain is a testing address until there is a real one. Put each tag where the
top of the phone's back sits on the pad, a few centimetres toward the top edge
from the coil. A tag on top of the coil either doesn't read or gets warm.

**Lights.** Either the box's own strip, on the radio's `LIGHT_PIN`, or a WLED
controller on the home Wi-Fi with four segments of two LEDs each — slot 1 is
segment 0, through to slot 4 as segment 3. With WLED the app switches a slot's
segment on when its tag is read, and never turns the controller off.

**Links live under `/p/`.** A slot is `/p/<secret>/<slot>`; the box's code is
`/p/<secret>`, the shape the first printed cards had, so every phone that
ever opened one already opens it. Slot links were `/d/` at first, and a phone
installed before `/d/` existed kept sending them to Safari: iOS caches the
site's `apple-app-site-association` for days, separately from the app. The site
now claims every path except the home page. Old `/d/` tags still read.

**Site.** `links/` must be deployed for these links to open the app.

## Trying it without a box

- On the simulator, with the **Reclaim (Sample data)** scheme:
  `xcrun simctl openurl booted reclaim://d/<anything>/2` is a phone going into
  slot 2, and `reclaim://d/<anything>` is the box's code.
- On a desk: the radio's serial monitor takes `1`–`4` to fill or empty a slot
  with no sensor wired.

## Known gaps

- **More than one WLED in the house.** The first controller found gets used.
- **A force-quit app** can't be woken over Bluetooth until it's opened again.
  The tag still opens it.

## The radio

A sensor under each slot and a small Bluetooth radio (`firmware/box/box.ino`).
The phone pairs with its box once, when it first reads the box's code or a
tag: the dock it's closest to at that moment is its box (`Box.closest`, -75 or
stronger). After that it stays connected whenever it's in range, and iOS
wakes the app when the box reports a change.

1. A phone lands. The slot's sensor changes, and the box lights that slot
   itself and tells every connected phone — its slot state and a `docked`
   event, below.
2. Every phone in range wakes for a few seconds and asks itself whether that
   was it (`Box.isThisPhone`). It was if this phone has just started charging
   and the box's signal is strong (`Box.nearby`, -60). A phone already on the
   bedside charger, or charging in another room, is not the one.
3. That phone starts the evening at the box's place. Nobody touches anything.
4. A slot empties. Every phone in the box wakes, waits fifteen seconds
   (`Box.outGrace`), and the one that still isn't charging ends its evening.

A swiped-away app can't be woken over Bluetooth, so the tag stays as the way
in.

### The protocol

The Portside dock protocol, version 1, which the dock with a current sensor
on each pad speaks too. The ids are placeholders until production, and live in
`Box.swift` and `box.ino` only.

| | UUID | |
|---|---|---|
| Service | `6e400001-b5a3-f393-e0a9-0000706f7274` | advertised; phones scan for this, never the name |
| Slot state | `6e400010-…` | read, notify. A byte per slot: 0 empty, 1 charging, 2 full |
| Event | `6e400011-…` | notify. `{"v":1,"slot":1,"event":"docked","t":…}`; also `undocked`, `full`, `pong` |
| Command | `6e400020-…` | write. `{"cmd":"time","epoch":…}` (sent on every connect), `light`, `ping` |

The phone subscribes to slot state and events, reads the slot state once, and
sends the time. A slot state change and its event say the same thing, and the
phone acts on whichever arrives first. `full` changes nothing: a phone that has
stopped drawing much — at 100%, or paused at 80% — is still in. The box
advertises as `Portside-XXXX`, the end of its radio's address. It has no id of
its own; pairing goes by which dock is closest.

This box can only tell that something is in a slot, so it reports every phone
as charging, and leaves `mA` and `V` out of its events.

### Parts to test it

- **Board:** any ESP32 with Bluetooth LE, such as a Seeed XIAO ESP32-C3 or S3,
  or an ESP32-C3/S3 dev board. About $5–10. Not an ESP32-S2, which has no
  Bluetooth.
- **One sensor per slot.** Start with one slot.
  - **IR obstacle module** (FC-51 or similar, about $1 each). It sits in the
    slot floor beside the pad, looking up. The phone covers it and it pulls its
    output low. Set its distance with the trimmer. Matte black cases reflect
    the least IR, so try your darkest one.
  - **Lever microswitch** under a pad that floats a millimetre or two. It's the
    most certain, and the fiddliest to build.
  - **A push button** wired to ground: a whole slot on a desk, for proving the
    app before the drawer exists.
  - Not a magnet (Hall) sensor: the MagSafe pad's own magnets hold it on.
- **Lights (optional):** a WS2812 strip, two LEDs per slot, on `LIGHT_PIN`.
  Leave it at -1 to keep using the WLED controller.

### Flashing it

1. Install the Arduino IDE, the ESP32 board package, and **NimBLE-Arduino
   2.x** (checked with 2.5.1; 1.4.x has a different API). Add Adafruit
   NeoPixel if the board runs the lights. On an Apple-silicon Mac, install
   Rosetta first (`softwareupdate --install-rosetta`): one of the Arduino
   build tools is Intel-only and fails with "bad CPU type" without it.
2. NimBLE-Arduino allows three connections by default, and every phone in the
   house holds one. In the library's `src/nimconfig.h`, uncomment
   `// #define CONFIG_BT_NIMBLE_MAX_CONNECTIONS 3` near the top and make it
   **5** on an ESP32-C3. Not more: the C3's radio holds 6 things at once and
   advertising is one of them, and asking for more crashes the board on every
   boot. The sketch refuses to compile if it's set too high.
3. Run `scripts/dock-tags.sh` and write the four links onto the tags.
4. Set `SLOT_PINS` for your wiring, then flash. On a XIAO ESP32-C3 the defaults are
   D1–D4; keep sensors off D0, D8 and D9, which the chip reads at boot. Fit
   the antenna that comes with it: without it the range is a few centimetres. The serial monitor at 115200
   prints each event as it's sent, and takes `1`–`4` to fill or empty a slot
   with no sensor wired (`0` empties them all).

### Testing it

1. Build the app to the phone, and open it once.
2. Scan the box's code with the camera, or hold the phone to a slot's tag and
   tap its banner. That pairs the phone with the box, and asks about Bluetooth.
3. Take the phone out. Fifteen seconds later the evening ends, and its Live
   Activity with it. Put it back within the fifteen and nothing changes.
4. Lock the phone and put it back. The evening should start with no tap, and
   the app opens on it the next time you look.
5. Try a second phone already on another charger nearby: it shouldn't start.

### Known gaps in this version

- **The Live Activity comes by push.** iOS doesn't let an app woken in the
  background start one, so the phone asks the `start-live-activity` Edge
  Function, which starts it with a push (iOS 17.2+; migration 0015). Without
  the network, or on iOS 17.0–17.1, it appears the next time the app is opened.
- **Five phones per box.** The C3's radio holds five connections plus its
  advertisement. A sixth phone in the house can't stay connected, and uses
  the tag. An ESP32-S3 doesn't lift this; a different radio would.
- **Two boxes side by side** can pair a phone with the wrong one: pairing goes
  by the closest dock, and the box has no id to check it against.
- **Two phones in the same second** both start correctly, but each may record
  the other's slot number. The box lights its own slots, so only the phone's
  note of which slot it's in can be wrong.
- **A phone put on a charger elsewhere** at the moment a slot fills, close
  enough to the box, would count. The signal threshold is what stops it, and
  it may need tuning on a real box.
