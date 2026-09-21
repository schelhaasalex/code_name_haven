# Schema review

An adversarial pass over the data model in `BRIEF.md`, done before any of it
existed as migrations. Every finding below is fixed in `supabase/migrations/`
and asserted in `supabase/tests/01_schema_test.sql`, which runs green.

```
supabase/tests/run.sh          # 16 assertions, all passing
```

Three of these were found only by **executing** the SQL rather than reading it.
That is the argument for doing it this way.

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

**The test harness stubs `auth`.** `supabase/tests/00_local_auth_stub.sql` fakes
`auth.users` and `auth.uid()` so the migrations run against bare Postgres. It is
never applied to a real project, and it means the tests prove the *logic* rather
than the Supabase integration.
