# The box

Four slots in a drawer. Each slot has a MagSafe-style charging pad, an NFC tag
under where the top of the phone lands, and a light on the outside of the box.
Putting your phone in the box **is** the confirmation: it starts the evening,
the way setting it down does. Taking it out turns its light off and nothing
else, because only the person ends an evening.

This is the first version, where the phone reads a tag. The version where the
box notices the phone itself is at the bottom.

## What happens

1. The phone goes into a slot and snaps onto the pad. On the way in it reads
   the slot's tag: `https://<LINK_DOMAIN>/d/<box secret>/<slot>`.
2. iOS shows a banner. One tap opens the app. (With the optional "NFC tag
   scanned" automation, there is no tap.)
3. The app turns that slot's light on (`DockLight`, never waited on). Then it
   finds or makes the box's place (`dock_place`, migration 0013) and starts the
   evening there, or moves an evening that's already running there.
4. The phone comes out. With the optional "charger disconnected" automation
   running **Take my phone out of the box** (`UndockIntent`), the light goes
   off at once. Without it, the light goes off when the evening ends, or the
   next time the app opens and the phone isn't charging.

A box with no lights, a declined Local Network prompt, or a controller on
another Wi-Fi: the light stays off and the evening counts all the same.

## The box's place

All four tags carry one secret, and it works like a card's secret: it is the
join credential. The box has no owner until someone uses it. The first phone
set into it makes its place, and every phone after that lands in the same
place. The secret is unique in the database, so two phones going in at the same
moment still make one place.

## Building one

**Tags.** `scripts/dock-tags.sh` prints four links under a fresh secret. Write
each one onto its slot's tag as a URL record (NFC Tools does this). Use one
secret per box, and **never lock the tags**: the domain is a testing address
until there is a real one. Put each tag where the top of the phone's back sits
on the pad, a few centimetres toward the top edge from the coil. A tag on top
of the coil either doesn't read or gets warm.

**Lights.** A WLED controller on the home Wi-Fi, with four segments of two LEDs
each. Slot 1 is segment 0, through to slot 4 as segment 3. Set the segments up
once in WLED's LED settings. The app only switches a segment on or off. It
turns on the controller as a whole when lighting a slot, and never turns it off.

**Site.** `links/` must be deployed for `/d/` links to open the app. Apple
caches `apple-app-site-association`, so a phone may need the app reinstalled
before it notices a new path.

## Trying it without a box

- Any NTAG sticker holding one of the four links, plus a WLED board on the same
  Wi-Fi, is a whole slot.
- On the simulator: `xcrun simctl openurl booted reclaim://d/<anything>/2`.
  There is no light there and no tag, but the evening starts.

## Known gaps

- **More than one WLED in the house.** The first controller found gets used.
- **A force-quit app** still opens from the tag's banner. It can't be woken any
  other way.
- **A phone that comes out** without the charger automation keeps its slot lit
  until the evening ends or the app next opens. The box can show one phone too
  many, but never one too few.

## The box notices (Bluetooth)

The tag needs a tap. To remove it, the box gets a sensor under each slot and a
small Bluetooth radio (`firmware/box/box.ino`). The phone pairs with its box
once, from the first tag it reads there. After that it stays connected
whenever it's in range, and iOS wakes the app when the box reports a change.

1. A phone lands. The slot's sensor changes, and the box lights that slot
   itself and tells every connected phone (one byte, a bit per slot).
2. Every phone in range wakes for a few seconds and asks itself whether that
   was it (`Box.isThisPhone`). It was if this phone has just started charging
   and the box's signal is strong (`Box.nearby`, -60). A phone already on the
   bedside charger, or charging in another room, is not the one.
3. That phone starts the evening at the box's place. Nobody touches anything.
4. A slot empties. The phone that was in it stops charging, and forgets its
   slot. The evening carries on.

The radio says who the box is with eight bytes of the secret's hash, never the
secret. A swiped-away app can't be woken over Bluetooth, so the tag stays as
the way in.

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
   1.4.x** (2.x changed its API). Add Adafruit NeoPixel if the board runs the
   lights.
2. NimBLE-Arduino allows three connections by default, and every phone in the
   house holds one. Raise `CONFIG_BT_NIMBLE_MAX_CONNECTIONS` to 9 in the
   library's `src/nimconfig.h`.
3. Run `scripts/dock-tags.sh`. Write the four links onto the tags, and put its
   `BOX_ID_HEX` into the sketch. **Both come from the same run.**
4. Set `SLOT_PINS` for your wiring, then flash. The serial monitor at 115200
   prints `slots 01` when slot 1 fills.

### Testing it

1. Build the app to the phone, and open it once.
2. Put the phone in a slot and tap the tag's banner. That pairs the phone with
   the box, and asks about Bluetooth.
3. Take the phone out, lock it, and put it back. The evening should start with
   no tap, and the app opens on it the next time you look.
4. Try a second phone already on another charger nearby: it shouldn't start.

### Known gaps in this version

- **No Live Activity, at first.** iOS doesn't let an app woken in the
  background start one. The evening counts, and the Live Activity appears the
  next time the app is opened. Starting it remotely through a push is the fix.
- **Two phones in the same second** both start correctly, but each may record
  the other's slot number. The box lights its own slots, so only the phone's
  note of which slot it's in can be wrong.
- **A phone put on a charger elsewhere** at the moment a slot fills, close
  enough to the box, would count. The signal threshold is what stops it, and
  it may need tuning on a real box.
