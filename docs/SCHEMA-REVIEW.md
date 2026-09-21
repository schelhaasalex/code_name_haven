# Schema review

An adversarial pass over the data model in `BRIEF.md`, done before any of it
existed as migrations. Every finding below is fixed in `supabase/migrations/`
and asserted in `supabase/tests/01_schema_test.sql`, which runs green.

```
supabase/tests/run.sh          # 19 assertions, all passing
```

Three were found only by **executing** the SQL against a local Postgres, and
two more only by applying it to a real hosted project. That is the argument
for doing it this way rather than reading carefully.

---

## Findings

### 1. The join race produced two gatherings at one table

Two people tap *Set it down* within a couple of seconds, neither having seen the
other's broadcast. Both created a gathering. Screen 5 then showed "two of you"
on one phone and "three of you" on another, permanently, and the evening was
recorded as two separate events.

**Fix.** A partial unique index — at most one *open* gathering per place —
plus `app.start_or_join`, which catches the resulting `unique_violation` and
joins the winner instead. An open gathering at a place always beats creating
one. `NULL` place ids are distinct under a unique index, so solo and
"Somewhere" gatherings are unaffected.

### 2. Evenings were inflating by household size

"31 evenings" would have counted five people at one dinner as five. Screen 9's
numbers would have been roughly 5× too high for a family and correct for
someone living alone, which is the worst kind of wrong — plausible.

**Fix.** `COUNT(DISTINCT local_date)` over qualifying sessions, in
`app.place_summary`.

### 3. "68h together here" meant two different things

Five people × 2h14m is either 2h14m of wall clock or 11h10m of person-hours,
and the brief named neither.

**Fix.** Both, named apart. `wall_clock_minutes` is how long the room was
gathered and does not grow with household size — that is what screen 9 shows.
`person_minutes` is summed across people and is the "hours reclaimed"
supporting metric.

### 4. `place_id` existed on both sessions and gatherings

Two copies of one fact, free to disagree — a gathering at The Kitchen Table
containing a session that claimed to be Somewhere.

**Fix.** Deleted from `sessions`. The gathering owns the place; a solo session
is a gathering of one. This also gives `app.name_somewhere` one clear thing to
update.

### 5. The visibility promise was unenforceable as designed

Screen 10 promises *"they see that you were there, never how often you
weren't."* If co-present users could select each other's session rows, anyone
with the anon key could enumerate a person's entire history. RLS controls rows,
not aggregates — it cannot express "readable in aggregate but not enumerable."

**Fix.** `sessions` is `profile_id = auth.uid()` for select, full stop. The same
for `profiles`. Co-presence is exposed only through `app.gathering_members` and
`app.place_summary`, which are `SECURITY DEFINER`, check membership first, and
return aggregates. This is a real constraint on the client: **it may not read
other people's rows directly, ever.**

### 6. `join_secret_hash` was readable — column grants don't work that way

*Found by running it.* The plan was a table-level `GRANT SELECT` with a
column-level `REVOKE` on the secret. PostgreSQL does not allow that: a
table-level grant covers every column and a column revoke cannot carve one back
out. The secret was selectable by any authenticated user.

**Fix.** The grant itself is column-scoped. While fixing it, all the grants got
narrowed: gatherings and sessions are not insertable or updatable by clients at
all, because the RPCs are the only place the invariants live. RLS became a
second line rather than the only one.

### 7. `pgcrypto` landed in the wrong schema

*Found by running it.* `create extension if not exists pgcrypto` installs into
`public`, but every function sets an empty `search_path` (so a hostile
search_path can't redirect a call), which means `digest()` must be
schema-qualified. `extensions.digest` would have failed at runtime on the first
card scan — and only then, because plpgsql doesn't resolve names until
execution.

**Fix.** The extension is created in `extensions`, matching Supabase's own
convention.

### 8. Merging bricked a printed card

Deleting the merged-away place would have stopped its NFC tag resolving, in
someone's hallway, with no way to tell.

**Fix.** `merged_into` on the source place, which is kept. `app.resolve_place`
follows the chain (with a depth guard) so an old tag lands on the survivor.

### 9. A place could end up ownerless

*Found by testing.* Ownership transfer on account deletion worked only if
someone else had qualifying evenings there. Otherwise `created_by` went `NULL`
and the place became permanently unrenameable, since only the owner can rename.

**Fix.** A fallback to the longest-standing remaining member.

### 10. There was no way to leave a place

`place_people` was append-only, so a friend's house you visited once was in your
list forever, and you were in their member list forever.

**Fix.** `left_at`, respected by `app.my_place_ids` and therefore by every
policy that keys off it.

### 11. `rhythms` was a cached table that could drift

It is fully derivable from sessions, and a cached copy needs a trigger or a job
to stay honest.

**Fix.** `app.my_rhythm()`, computed on demand. The data is a few hundred rows
per person per year, so there is no performance argument for caching it.

### 12. Smaller things, now constrained rather than hoped for

- A live session could be marked `qualifying`. Now a check constraint forbids it,
  so anything counting evenings cannot see half-finished rows.
- Nothing stopped two live sessions for one person, or joining one gathering
  twice. Both are unique indexes now.
- `duration_minutes` could disagree with `ended_at` being null. Check constraint.
- Auto-close credits **at the cap**, in `app.auto_close_stale` — nine hours of
  phone-on-the-side becomes 180 minutes. Without this the cheapest strategy in
  the product is to start a session and walk away.
- Retroactive sessions are forced solo and placeless: nobody was broadcasting,
  so co-presence cannot be reconstructed after the fact and must not be invented.
- The qualifying minimum and auto-close ceiling are `IMMUTABLE` functions, not
  configuration, matching screen 16 stating them as facts.

---

## Two more, found only on a hosted project

The local scratch Postgres proved the logic. It could not prove the platform.
Both of these appeared the moment the migrations ran against real Supabase.

### 13. `anon` had `GRANT ALL` on every table

A hosted project ships with

```sql
alter default privileges in schema public
  grant all on tables to postgres, anon, authenticated, service_role;
```

so every table created by `0001` arrived carrying a table-level `GRANT ALL` to
both `anon` and `authenticated` — which silently undid the column-scoped grant
that keeps `join_secret_hash` unreadable, and handed the unauthenticated role
blanket privileges on all five tables.

RLS would still have denied `anon` every row, since it has no `auth.uid()`. But
column privileges are not row privileges, and a single policy mistake would
then have been the only thing between a scraper and the join secrets.

**Fix.** `0002` now revokes the defaults from `anon` and `authenticated` before
granting anything, and uses `alter default privileges` so tables added by
future migrations don't quietly re-acquire them. Verified on the live project:
`anon` holds **zero** privileges in `public`, and `authenticated` holds exactly
`gatherings: SELECT`, `place_people: INSERT,SELECT`, `profiles:
INSERT,SELECT,UPDATE`, `sessions: DELETE,SELECT`, plus column-scoped SELECT on
`places` with `join_secret_hash` absent and `name` the only updatable column.

### 14. Three functions had a mutable `search_path`

Supabase's own database linter flagged `app.qualifying_minutes`,
`app.auto_close_minutes` and `app.place_stage`
([0011_function_search_path_mutable](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable)).
They take no tables and reference nothing schema-qualified, so the practical
risk is small — but every other function here pins it, and consistency is
cheaper than a judgement call each time someone adds one. Fixed in `0004`.

The linter now reports **no findings**.

---

## One found from the client side

### 15. The ceremony ran on public Realtime channels

Found while fixing the client's broadcast decoding, not by reading SQL: the
live check that proved the fix worked needed no sign-in at all. Anyone holding
the publishable key — which ships inside the app — could subscribe to
`gathering:<id>` or `place:<id>` and hear who set their phone down and when,
names included. Row level security never saw it, because public channels don't
consult the database. Rule 1, broken by a side door.

**Fix.** `0006` puts listen (SELECT) and send (INSERT) policies on
`realtime.messages`, built on the existing `app.my_gathering_ids()` and
`app.my_place_ids()`, so a channel is never wider than the tables behind it.
Broadcast only — presence would be a roster of who is connected. The client
joins both channel kinds with `isPrivate = true`.

One trap inside the fix: Swift's `uuidString` is uppercase and Postgres prints
uuids in lowercase, so an exact comparison would have refused every join, and
a refused join is a channel that simply hears nothing. The policy lowercases
the topic, the client sends it lowercase, and both are tested.

Assertion 15 runs the policies locally against a stub of `realtime` shaped
after the hosted one. The same eight cases were then run on the hosted project,
against the real partitioned table, inside a transaction that raised on purpose
so nothing was kept: members listen and send, uppercase topics match,
strangers, `anon`, presence and malformed topics are refused. The linter
reports nothing.

With public and private channels being separate even under the same topic,
the client change is what closes the leak. Turning off **Allow public access**
under Realtime → Settings refuses public channels outright, as a second line.

---

## Verified against the live project

Beyond the offline assertions, the full flow was run once on the hosted
database through the real `auth.uid()` path, with a throwaway user deleted
afterwards: create a place, start a session by tag, end it, and read back
`place_summary` (1 evening, 120 wall-clock minutes, stage "new here", no longer
live), `my_rhythm` (in_rhythm, run of 1), and `resolve_place` — which found the
place by its secret and returned null for a wrong one.

## Deliberately not built

**Depth-one hierarchy.** No `site_id`. Sessions always happen at a leaf, so a
parent is only ever a reporting concern and can be added later without touching
the session model. The likely failure is fragmentation, not missing nesting, and
the fix for that is merge — which exists.

**`pucks`.** v2. `sessions.puck_id` is present and always null, which is the
only hook the hardware needs.

**Scheduling.** `app.auto_close_stale()` needs `pg_cron` (or an edge function on
a timer) and is deliberately *not* granted to `authenticated` — it runs from a
scheduler, not a client.

**Realtime.** The publication for the ceremony broadcast isn't configured yet.
That belongs with step 3 of the build order, since the broadcast is a channel
message rather than a table change.

---

## What I'd still want before trusting this

**`app.my_rhythm` deserves more tests than the two it has.** The rest-day rule —
a run survives one missed day if a rest day is unspent for that ISO week — is
the fiddliest logic here, and the two cases covered (a forgiven gap, and a break
that banks its days) are not the whole space. Year boundaries, timezone travel
making `local_date` non-monotonic, and two gaps in adjacent weeks are all
untested.

**The indexes are a guess.** They cover the queries the twenty-one screens
actually make, but no real data has touched them.

**The harness had stopped running, and nobody noticed.** Fixing finding 13
added `revoke ... from anon` to `0002`, but `run.sh` only ever created the
`authenticated` role — so every run since then died on
`role "anon" does not exist`, while the README went on claiming sixteen green
assertions. It also applied `0001`–`0003` and stopped, leaving `0004` and the
`0005` wrappers — the functions the client actually calls — untested locally.
Both are fixed, the suite runs green against all seven migrations, and assertion
12 now checks the wrapper surface: ten functions callable by `authenticated`,
`app.auto_close_stale` callable by neither, `anon` holding nothing. A test
suite that isn't run by something is a test suite that has stopped;
`.github/workflows/checks.yml` now runs this one on every pull request.

**The test harness stubs `auth`.** `supabase/tests/00_local_auth_stub.sql` fakes
`auth.users` and `auth.uid()` so the migrations run against bare Postgres. It is
never applied to a real project, and it means the tests prove the *logic* rather
than the Supabase integration.
