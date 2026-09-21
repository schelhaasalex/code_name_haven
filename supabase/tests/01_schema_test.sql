-- Reclaim — schema tests.
--
-- Each block asserts one of the findings from docs/SCHEMA-REVIEW.md is actually
-- fixed. Run against a scratch Postgres with the local auth stub:
--   supabase/tests/run.sh
--
-- Any failure raises and aborts the transaction, so a clean run means every
-- assertion below held.

\set ON_ERROR_STOP on

grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;

-- ---------------------------------------------------------------- fixtures

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alex@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'maya@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'dad@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'sam@example.test');

insert into profiles (id, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'Alex'),
  ('22222222-2222-2222-2222-222222222222', 'Maya'),
  ('33333333-3333-3333-3333-333333333333', 'Dad'),
  ('44444444-4444-4444-4444-444444444444', 'Sam');

-- ============================================================ FINDING 1
-- The join race. Two people tap within seconds of each other, neither having
-- seen the other's broadcast. They must land in ONE gathering.

do $$
declare v_place uuid; v_gatherings int; v_sessions int;
begin
  perform auth.login('11111111-1111-1111-1111-111111111111');
  v_place := app.create_place('amber-otter', 'a-very-long-random-secret', 'The Kitchen Table');
  perform app.start_or_join(v_place, 'tag', 'UTC');

  perform auth.login('22222222-2222-2222-2222-222222222222');
  perform app.start_or_join(v_place, 'app', 'UTC');

  perform auth.login('33333333-3333-3333-3333-333333333333');
  perform app.start_or_join(v_place, 'siri', 'UTC');

  select count(*) into v_gatherings from gatherings where place_id = v_place;
  select count(*) into v_sessions   from sessions s
    join gatherings g on g.id = s.gathering_id where g.place_id = v_place;

  assert v_gatherings = 1, format('expected 1 gathering, got %s', v_gatherings);
  assert v_sessions  = 3, format('expected 3 sessions, got %s', v_sessions);
  raise notice 'PASS  1  three people, one gathering';
end $$;

-- The unique index is the real guard; prove it rejects a second open gathering.
do $$
declare v_place uuid; v_failed boolean := false;
begin
  select id into v_place from places where handle = 'amber-otter';
  begin
    insert into gatherings (place_id, started_by)
    values (v_place, '11111111-1111-1111-1111-111111111111');
  exception when unique_violation then
    v_failed := true;
  end;
  assert v_failed, 'a second open gathering at one place should be rejected';
  raise notice 'PASS  1b index rejects a concurrent second gathering';
end $$;

-- ============================================================ FINDING 2
-- Evening counting. One dinner with three people is ONE evening, not three.
-- And the two hour figures must differ in the right direction.

do $$
declare
  v_place uuid; v_row record;
begin
  select id into v_place from places where handle = 'amber-otter';

  -- Wind the clock back so the sessions have real duration, then end them.
  update sessions s set started_at = now() - interval '2 hours'
    from gatherings g where g.id = s.gathering_id and g.place_id = v_place;
  update gatherings set started_at = now() - interval '2 hours' where place_id = v_place;

  perform auth.login('11111111-1111-1111-1111-111111111111'); perform app.end_session();
  perform auth.login('22222222-2222-2222-2222-222222222222'); perform app.end_session();
  perform auth.login('33333333-3333-3333-3333-333333333333'); perform app.end_session();

  perform auth.login('11111111-1111-1111-1111-111111111111');
  select * into v_row from app.place_summary(v_place);

  assert v_row.evenings = 1,
    format('one dinner with three people must be 1 evening, got %s', v_row.evenings);
  assert v_row.wall_clock_minutes between 118 and 122,
    format('wall clock should be ~120, got %s', v_row.wall_clock_minutes);
  assert v_row.person_minutes between 355 and 365,
    format('person minutes should be ~360, got %s', v_row.person_minutes);
  assert v_row.stage = 'new here', format('stage was %s', v_row.stage);
  assert v_row.live_now = false, 'gathering should have closed when the last person left';
  raise notice 'PASS  2  1 evening, wall clock % min, person % min',
    v_row.wall_clock_minutes, v_row.person_minutes;
end $$;

-- ============================================================ FINDING 3
-- Visibility. Screen 10 promises the people you dock with never see how often
-- you weren't there. Other people's session rows must be unreadable.

do $$
declare v_mine int; v_profiles int; v_members int;
begin
  set local role authenticated;
  perform auth.login('22222222-2222-2222-2222-222222222222');

  select count(*) into v_mine from sessions;
  assert v_mine = 1, format('Maya should see only her own session, saw %s', v_mine);

  select count(*) into v_profiles from profiles;
  assert v_profiles = 1, format('Maya should see only her own profile, saw %s', v_profiles);

  -- But co-presence still works, through the aggregate function.
  select count(*) into v_members
    from app.gathering_members((select gathering_id from sessions limit 1));
  assert v_members = 3, format('gathering_members should show 3, got %s', v_members);

  reset role;
  raise notice 'PASS  3  own rows only (1 session, 1 profile), co-presence still returns 3';
end $$;

-- A stranger must not be able to read a gathering they were not in.
do $$
declare v_failed boolean := false; v_gathering uuid;
begin
  select id into v_gathering from gatherings limit 1;
  set local role authenticated;
  perform auth.login('00000000-0000-0000-0000-0000000000ff');
  begin
    perform app.gathering_members(v_gathering);
  exception when others then
    v_failed := true;
  end;
  reset role;
  assert v_failed, 'a non-member must not read gathering members';
  raise notice 'PASS  3b non-members are refused';
end $$;

-- The join secret must not be selectable, even by a legitimate member.
do $$
declare v_failed boolean := false;
begin
  set local role authenticated;
  perform auth.login('11111111-1111-1111-1111-111111111111');
  begin
    perform join_secret_hash from places limit 1;
  exception when insufficient_privilege then
    v_failed := true;
  end;
  reset role;
  assert v_failed, 'join_secret_hash must not be selectable by clients';
  raise notice 'PASS  3c join secret is not readable';
end $$;

-- ============================================================ FINDING 4
-- Merging must not brick a card already stuck to a door.

do $$
declare v_a uuid; v_b uuid; v_resolved uuid;
begin
  perform auth.login('11111111-1111-1111-1111-111111111111');
  v_a := (select id from places where handle = 'amber-otter');
  v_b := app.create_place('quiet-heron', 'another-long-random-secret', 'The Kitchen');

  perform app.merge_places(v_b, v_a);

  v_resolved := app.resolve_place('another-long-random-secret');
  assert v_resolved = v_a,
    'the merged-away card must resolve to the surviving place';
  assert (select merged_into from places where id = v_b) = v_a,
    'merged_into should point at the survivor';
  raise notice 'PASS  4  a merged card still resolves';
end $$;

-- ============================================================ FINDING 5
-- Auto-close credits at the cap, never at the wall-clock time the phone sat
-- there. Otherwise "start one and walk away" is the cheapest strategy.

do $$
declare v_place uuid; v_n int; v_row record;
begin
  perform auth.login('11111111-1111-1111-1111-111111111111');
  v_place := app.create_place('slow-heron', 'third-long-random-secret', 'The Office');
  perform app.start_or_join(v_place, 'app', 'UTC');

  -- Pretend the phone sat there for nine hours.
  update sessions set started_at = now() - interval '9 hours' where ended_at is null;
  update gatherings set started_at = now() - interval '9 hours' where ended_at is null;

  v_n := app.auto_close_stale();
  assert v_n = 1, format('expected 1 auto-closed session, got %s', v_n);

  select * into v_row from sessions where auto_closed;
  assert v_row.duration_minutes = 180,
    format('auto-closed session must credit the 180 minute cap, got %s', v_row.duration_minutes);
  assert v_row.qualifying, 'a capped session still counts toward the day';
  raise notice 'PASS  5  nine hours credited as 180 minutes';
end $$;

-- ============================================================ FINDING 6
-- Retroactive credit is always solo and always placeless — nobody was
-- broadcasting, so co-presence cannot be invented after the fact.

do $$
declare v_id uuid; v_row record;
begin
  perform auth.login('22222222-2222-2222-2222-222222222222');
  v_id := app.record_retroactive(now() - interval '3 hours', now() - interval '80 minutes', 'UTC');
  select s.*, g.place_id into v_row
    from sessions s join gatherings g on g.id = s.gathering_id where s.id = v_id;

  assert v_row.retroactive, 'should be flagged retroactive';
  assert v_row.place_id is null, 'a retroactive session must have no place';
  assert v_row.duration_minutes = 100,
    format('expected 100 minutes, got %s', v_row.duration_minutes);
  assert v_row.qualifying, '100 minutes is well past the 15 minute floor';
  raise notice 'PASS  6  retroactive session is solo, placeless, 100 min';
end $$;

-- ============================================================ FINDING 7
-- A live session has not qualified yet, and there can only be one at a time.

do $$
declare v_place uuid; v_failed boolean := false;
begin
  perform auth.login('33333333-3333-3333-3333-333333333333');
  v_place := (select id from places where handle = 'amber-otter');
  perform app.start_or_join(v_place, 'app', 'UTC');

  assert not exists (select 1 from sessions where ended_at is null and qualifying),
    'a live session must never be marked qualifying';

  begin
    insert into sessions (profile_id, gathering_id, local_date)
    values ('33333333-3333-3333-3333-333333333333',
            (select id from gatherings where ended_at is null limit 1),
            current_date);
  exception when unique_violation then
    v_failed := true;
  end;
  assert v_failed, 'a person may only have one live session';

  perform app.end_session();
  raise notice 'PASS  7  one live session per person, never pre-qualified';
end $$;

-- ============================================================ FINDING 8
-- Rhythms. A run survives a single missed day if a rest day is unspent for
-- that ISO week; the rest day covers the gap without counting as an evening.

do $$
declare v_gather uuid; v_row record; d date;
begin
  perform auth.login('22222222-2222-2222-2222-222222222222');
  delete from sessions where profile_id = '22222222-2222-2222-2222-222222222222';

  -- Six consecutive days ending today, with one day missing four days ago.
  foreach d in array array[
      current_date - 6, current_date - 5, current_date - 4,
      -- current_date - 3 deliberately missing
      current_date - 2, current_date - 1, current_date]
  loop
    insert into gatherings (place_id, started_by, started_at, ended_at)
    values (null, '22222222-2222-2222-2222-222222222222',
            d::timestamptz, d::timestamptz + interval '1 hour')
    returning id into v_gather;
    insert into sessions (profile_id, gathering_id, started_at, ended_at,
                          duration_minutes, local_date, qualifying)
    values ('22222222-2222-2222-2222-222222222222', v_gather,
            d::timestamptz, d::timestamptz + interval '1 hour', 60, d, true);
  end loop;

  select * into v_row from app.my_rhythm();
  assert v_row.state = 'in_rhythm', format('expected in_rhythm, got %s', v_row.state);
  assert v_row.current_run_days = 6,
    format('six evenings across a forgiven gap should be a run of 6, got %s',
           v_row.current_run_days);
  assert v_row.last_qualifying_date = current_date, 'last date should be today';
  raise notice 'PASS  8  run of % across a forgiven gap, state %',
    v_row.current_run_days, v_row.state;
end $$;

-- Two missed days in one week breaks the run; the days already banked survive
-- as longest_run_days, which is what screen 14 promises.
do $$
declare v_gather uuid; v_row record; d date;
begin
  perform auth.login('33333333-3333-3333-3333-333333333333');
  delete from sessions where profile_id = '33333333-3333-3333-3333-333333333333';

  foreach d in array array[current_date - 20, current_date - 19, current_date - 18,
                           current_date - 17, current_date - 16]
  loop
    insert into gatherings (place_id, started_by, started_at, ended_at)
    values (null, '33333333-3333-3333-3333-333333333333',
            d::timestamptz, d::timestamptz + interval '1 hour')
    returning id into v_gather;
    insert into sessions (profile_id, gathering_id, started_at, ended_at,
                          duration_minutes, local_date, qualifying)
    values ('33333333-3333-3333-3333-333333333333', v_gather,
            d::timestamptz, d::timestamptz + interval '1 hour', 60, d, true);
  end loop;

  select * into v_row from app.my_rhythm();
  assert v_row.state = 'between', format('expected between, got %s', v_row.state);
  assert v_row.current_run_days = 0, 'a broken rhythm has no current run';
  assert v_row.longest_run_days = 5,
    format('the five days that happened must survive, got %s', v_row.longest_run_days);
  raise notice 'PASS  8b between rhythms, five banked days survive';
end $$;

-- ============================================================ FINDING 9
-- The stage ladder only ever moves forward, and the thresholds match screen 9
-- (31 evenings is a reclaim house; a landmark starts at fifty).

do $$
begin
  assert app.place_stage(0)  = 'new here';
  assert app.place_stage(4)  = 'new here';
  assert app.place_stage(5)  = 'a regular table';
  assert app.place_stage(19) = 'a regular table';
  assert app.place_stage(20) = 'a reclaim house';
  assert app.place_stage(31) = 'a reclaim house';
  assert app.place_stage(49) = 'a reclaim house';
  assert app.place_stage(50) = 'a landmark';
  raise notice 'PASS  9  stage thresholds match screen 9';
end $$;

-- ============================================================ FINDING 10
-- Deleting an account leaves the place standing, with ownership falling to
-- whoever has the most evenings there.

do $$
declare v_place uuid; v_owner uuid; v_gather uuid; d date;
begin
  v_place := (select id from places where handle = 'amber-otter');
  assert (select created_by from places where id = v_place)
         = '11111111-1111-1111-1111-111111111111', 'Alex should own it first';

  -- Give Dad two qualifying evenings here so the "most evenings" path is the
  -- one under test rather than the fallback.
  foreach d in array array[current_date - 9, current_date - 8] loop
    insert into gatherings (place_id, started_by, started_at, ended_at)
    values (v_place, '33333333-3333-3333-3333-333333333333',
            d::timestamptz, d::timestamptz + interval '1 hour')
    returning id into v_gather;
    insert into sessions (profile_id, gathering_id, started_at, ended_at,
                          duration_minutes, local_date, qualifying)
    values ('33333333-3333-3333-3333-333333333333', v_gather,
            d::timestamptz, d::timestamptz + interval '1 hour', 60, d, true);
  end loop;

  delete from profiles where id = '11111111-1111-1111-1111-111111111111';

  select created_by into v_owner from places where id = v_place;
  assert exists (select 1 from places where id = v_place), 'the place must survive its owner';
  assert v_owner = '33333333-3333-3333-3333-333333333333',
    format('ownership should have moved to the most frequent visitor, got %s', v_owner);
  raise notice 'PASS 10  place survived, ownership moved to the most frequent visitor';
end $$;

-- And when nobody has evenings yet, it falls to the longest-standing member
-- rather than leaving the place ownerless and therefore unrenameable.
do $$
declare v_place uuid; v_owner uuid;
begin
  perform auth.login('44444444-4444-4444-4444-444444444444');
  v_place := app.create_place('plain-marten', 'fifth-long-random-secret', 'The Spare Room');
  insert into place_people (place_id, profile_id)
  values (v_place, '33333333-3333-3333-3333-333333333333');

  delete from profiles where id = '44444444-4444-4444-4444-444444444444';

  select created_by into v_owner from places where id = v_place;
  assert v_owner = '33333333-3333-3333-3333-333333333333',
    format('ownership should have fallen to the remaining member, got %s', v_owner);
  raise notice 'PASS 10b ownerless fallback works';
end $$;

-- ============================================================ FINDING 11
-- Naming a "Somewhere" bucket moves its history onto the new place.

do $$
declare v_place uuid; v_moved int;
begin
  perform auth.login('22222222-2222-2222-2222-222222222222');
  v_place := app.name_somewhere('calm-badger', 'fourth-long-random-secret', 'The Deck');

  select count(*) into v_moved
    from gatherings g
    join sessions s on s.gathering_id = g.id
   where g.place_id = v_place
     and s.profile_id = '22222222-2222-2222-2222-222222222222';

  assert v_moved >= 6,
    format('naming should have adopted the placeless history, moved %s', v_moved);
  raise notice 'PASS 11  % placeless gatherings adopted by the new place', v_moved;
end $$;

-- ============================================================ THE CLIENT API
-- 0005 exists because PostgREST only serves exposed schemas, and `app` is not
-- one: every RPC would have 404'd. The failure reads like a missing function
-- rather than a config gap, so it is asserted rather than remembered.

do $$
declare v_missing text; v_wrapped int; v_anon int;
begin
  for v_missing in
    select name from unnest(array[
      'resolve_place', 'create_place', 'start_or_join', 'end_session',
      'record_retroactive', 'gathering_members', 'place_summary', 'my_rhythm',
      'name_somewhere', 'merge_places']) as name
    where not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = name)
  loop
    assert false, format('public.%s is missing — the client would get a 404', v_missing);
  end loop;

  select count(*) into v_wrapped
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and has_function_privilege('authenticated', p.oid, 'execute');
  assert v_wrapped = 10, format('expected 10 callable wrappers, found %s', v_wrapped);

  -- The scheduler's job is not a client's to call: nine hours of
  -- phone-on-the-side becoming 180 minutes has to happen TO you, not by you.
  assert not has_function_privilege('authenticated', 'app.auto_close_stale()', 'execute'),
    'auto_close_stale must not be callable by a phone';

  -- anon holds nothing, anywhere. Finding 13 was this being untrue.
  select count(*) into v_anon
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute');
  assert v_anon = 0, format('anon can execute %s functions in public', v_anon);

  raise notice 'PASS 12  ten wrappers callable by authenticated, none by anon';
end $$;

do $$ begin raise notice '--- all assertions held ---'; end $$;
