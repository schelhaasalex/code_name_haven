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

## Next: the box notices

Each pad gets its own sensor wired to the controller: pressure, infrared, or
current on the charger. Not a magnet sensor, because the MagSafe magnets would
always trigger it. The lights then follow the sensors directly, with no app
involved. A small Bluetooth chip in the box announces when a slot changes. That
wakes the app in the background, and the phone that just started charging,
with the box's signal very close, starts its evening with nobody touching
anything. After that, the tag is only needed once, to pair a phone with its box.
