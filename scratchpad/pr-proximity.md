## Join the table you're sitting at, with nothing to scan

One phone already face down, the others noticing from across the table. The
card works, but it has to exist — somebody printed it, it stayed where it was
put, and a guest thought to touch a phone to it. This is the same moment with
none of that. It's the puck's software rehearsal.

### What travels is a key, not an address

A place id would do the job and would never expire — so a phone in range for
one evening would hold a way into that house forever. The key `app.open_nearby()`
mints is worthless the moment the evening ends, which means joining by radio can
only ever put you at a table that is set **right now**.

What the other phone learns before it joins: that an evening near it is open,
how many phones are down, and when it started. No name, no place, no person —
so screen 4 says *"Someone nearby set theirs down."* and means it. (An invite
may name the place and who asked; by then you're one of its people.)

### The two halves are lopsided on purpose

- The phone that is **down** keeps advertising with the screen off. That's the
  only reason `bluetooth-peripheral` is in `UIBackgroundModes`.
- The phone still in a **hand** listens in the foreground only. The moment this
  is for is the one before you put it down, and scanning all evening would be a
  permission this feature hasn't earned.

The Bluetooth prompt happens at the dock, never at sign-in — "so the phones
around you can find this table" only means something a second after somebody
set a phone down. Until then the scanner doesn't exist. Nothing is gated on any
of it: Bluetooth off, refused or absent, and the evening runs exactly as it
would have (rules 4, 5 and 7).

### Database — migration 0010 (already applied to the hosted project)

- `nearby_keys`, hashed like every other secret here, readable by nobody.
- `open_nearby()` refuses an evening at no place: joining one over the air would
  make you one of the people of a place that doesn't exist yet. Name it and the
  table appears on the radio.
- `nearby_offer()` returns the gathering, the count and the time. Nothing else —
  asserted at the shape of the function, so adding a place id breaks a test.
- `join_nearby()` turns the key into a place inside the database and hands back
  only the gathering. Both ways in are the ones that already existed: an evening
  of your own moves to the table (0007), otherwise you join it like every other
  entrance (0003). Your start time doesn't move, so nothing about what counted
  changes.

### Checks

- 20 new assertion blocks in `supabase/tests/01_schema_test.sql` (113 assertions
  total now), two guards mutation-checked by breaking them first.
- `Nearby.key` refuses anything that doesn't look like ours before it becomes a
  request — any device can advertise these ids and answer with anything.
- A key gets one question, ever: the radio re-finds the same table every few
  seconds, and a question that comes back is the nagging this product replaces.
- New shape check — "a phone that is down keeps talking" — written to fail
  before it passed. Without the background mode the advertisement stops a second
  after the phone goes down and nothing anywhere says so.

### Still to verify on real hardware

Two phones, different Apple IDs: A docks at a place (allow Bluetooth), B opens
the app and should be offered the table within a few seconds.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
