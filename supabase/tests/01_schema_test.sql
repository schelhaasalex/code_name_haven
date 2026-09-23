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
      'name_somewhere', 'merge_places', 'move_evening',
      'create_invite', 'accept_invite', 'has_company',
      'open_nearby', 'nearby_offer', 'join_nearby', 'my_evenings']) as name
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
  assert v_wrapped = 18, format('expected 18 callable wrappers, found %s', v_wrapped);

  -- The scheduler's job is not a client's to call: nine hours of
  -- phone-on-the-side becoming 180 minutes has to happen TO you, not by you.
  assert not has_function_privilege('authenticated', 'app.auto_close_stale()', 'execute'),
    'auto_close_stale must not be callable by a phone';

  -- anon holds nothing, anywhere. Finding 13 was this being untrue.
  select count(*) into v_anon
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute');
  assert v_anon = 0, format('anon can execute %s functions in public', v_anon);

  raise notice 'PASS 12  eighteen wrappers callable by authenticated, none by anon';
end $$;

-- ============================================================ FINDING 15
-- Realtime. A private channel asks realtime.messages whether you may listen
-- (SELECT) or send (INSERT), with realtime.topic set to the channel. These
-- helpers do what Realtime does on join: a probe row, the topic, the person,
-- then the client's role. They live in their own schema so finding 12's count
-- of what's callable in public stays about the product.

create schema reclaim_test;
grant usage on schema reclaim_test to authenticated, anon;

create function reclaim_test.can_listen(p_role text, p_user uuid, p_topic text,
                                        p_ext text default 'broadcast')
returns boolean language plpgsql as $$
declare n int;
begin
  insert into realtime.messages (topic, extension, event) values (p_topic, p_ext, 'probe');
  perform set_config('realtime.topic', p_topic, true);
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  execute format('set local role %I', p_role);
  select count(*) into n from realtime.messages where topic = p_topic and event = 'probe';
  reset role;
  delete from realtime.messages where event = 'probe';
  return n > 0;
end $$;

create function reclaim_test.can_send(p_role text, p_user uuid, p_topic text)
returns boolean language plpgsql as $$
declare ok boolean := true;
begin
  perform set_config('realtime.topic', p_topic, true);
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  execute format('set local role %I', p_role);
  begin
    insert into realtime.messages (topic, extension, event) values (p_topic, 'broadcast', 'probe');
  exception when insufficient_privilege then
    ok := false;
  end;
  reset role;
  delete from realtime.messages where event = 'probe';
  return ok;
end $$;

grant execute on all functions in schema reclaim_test to authenticated, anon;

do $$
declare
  v_host     uuid := '55555555-5555-5555-5555-555555555555';
  v_stranger uuid := '66666666-6666-6666-6666-666666666666';
  v_place uuid; v_gathering uuid; g text; p text;
begin
  insert into auth.users (id, email) values (v_host, 'host@example.test'),
                                            (v_stranger, 'stranger@example.test');
  insert into profiles (id, display_name) values (v_host, 'Host'), (v_stranger, 'Stranger');

  perform auth.login(v_host);
  v_place := app.create_place('still-lantern', 'yet-another-long-random-secret', 'The Porch');
  perform app.start_or_join(v_place, 'app', 'UTC');
  select gathering_id into v_gathering from sessions where profile_id = v_host and ended_at is null;
  perform auth.logout();

  g := 'gathering:' || v_gathering;
  p := 'place:' || v_place;

  assert reclaim_test.can_listen('authenticated', v_host, g),     'a member must hear their gathering';
  assert reclaim_test.can_send('authenticated', v_host, g),       'a member must be able to send to it';
  assert reclaim_test.can_listen('authenticated', v_host, p),     'a member must hear their place';
  assert reclaim_test.can_send('authenticated', v_host, p),       'a member must be able to announce at it';

  -- The client builds topics from Swift's uuidString, which is uppercase.
  assert reclaim_test.can_listen('authenticated', v_host, upper(g)), 'an uppercase topic must still match';
  assert reclaim_test.can_send('authenticated', v_host, 'PLACE:' || upper(v_place::text)),
    'an uppercase place topic must still match';

  assert not reclaim_test.can_listen('authenticated', v_stranger, g), 'a stranger must not hear the gathering';
  assert not reclaim_test.can_send('authenticated', v_stranger, g),   'a stranger must not send to it';
  assert not reclaim_test.can_listen('authenticated', v_stranger, p), 'a stranger must not hear the place';
  assert not reclaim_test.can_send('authenticated', v_stranger, p),   'a stranger must not announce at it';

  assert not reclaim_test.can_listen('anon', null, g), 'anon must not hear anything';
  assert not reclaim_test.can_send('anon', null, p),   'anon must not send anything';

  -- Presence would be a roster of who is connected. Rule 3.
  assert not reclaim_test.can_listen('authenticated', v_host, g, 'presence'), 'presence must be refused';

  -- Refused, not an error inside a policy.
  assert not reclaim_test.can_listen('authenticated', v_host, 'gathering:not-a-uuid'), 'a malformed topic is refused';
  assert not reclaim_test.can_listen('authenticated', v_host, 'somewhere-else'),       'an unknown topic is refused';

  -- Leaving a place closes its channel to you.
  update place_people set left_at = now() where place_id = v_place and profile_id = v_host;
  assert not reclaim_test.can_listen('authenticated', v_host, p), 'someone who left must not hear the place';

  raise notice 'PASS 15  channels open to members only, uppercase topics match, anon and presence refused';
end $$;

-- ============================================================ 16
-- Scanning in after setting your phone down. The host started as Somewhere;
-- a friend arrives and taps the card, opening an evening at the place. The
-- host scans too, and must end up in the SAME evening as the friend — with
-- their own start time, so no credit changes.

do $$
declare
  v_host   uuid := '77777777-7777-7777-7777-777777777777';
  v_friend uuid := '88888888-8888-8888-8888-888888888888';
  v_place uuid; v_solo_place uuid;
  v_host_gathering uuid; v_friend_gathering uuid; v_moved uuid;
  v_started timestamptz; v_members int; v_failed boolean;
begin
  insert into auth.users (id, email) values (v_host, 'mover@example.test'),
                                            (v_friend, 'guest@example.test');
  insert into profiles (id, display_name) values (v_host, 'Mover'), (v_friend, 'Guest');

  perform auth.login(v_friend);
  v_place := app.create_place('open-hearth', 'a-card-on-the-hearth-secret', 'The Hearth');
  perform app.start_or_join(v_place, 'tag', 'UTC');
  select gathering_id into v_friend_gathering from sessions where profile_id = v_friend and ended_at is null;

  perform auth.login(v_host);
  perform app.start_or_join(null, 'app', 'UTC');
  select gathering_id, started_at into v_host_gathering, v_started
    from sessions where profile_id = v_host and ended_at is null;

  v_moved := app.move_evening(v_place);
  assert v_moved = v_friend_gathering, 'the host must land in the evening already open there';
  assert (select gathering_id from sessions where profile_id = v_host and ended_at is null) = v_friend_gathering,
    'the host''s session must have moved';
  assert (select started_at from sessions where profile_id = v_host and ended_at is null) = v_started,
    'moving must not change when the host started';
  assert not exists (select 1 from gatherings where id = v_host_gathering),
    'the empty placeless evening left behind must be gone';
  select count(*) into v_members from app.gathering_members(v_friend_gathering);
  assert v_members = 2, format('host and friend should share one evening, saw %s', v_members);
  assert exists (select 1 from place_people where place_id = v_place and profile_id = v_host and left_at is null),
    'the host must now belong to the place';

  -- Already here: nothing moves.
  assert app.move_evening(v_place) = v_friend_gathering, 'moving to where you are changes nothing';

  -- Alone, with nothing open at the place: the evening itself becomes the place's.
  perform app.end_session(null);
  v_solo_place := app.create_place('quiet-landing', 'a-card-on-the-landing-secret', 'The Landing');
  perform app.start_or_join(null, 'app', 'UTC');
  select gathering_id into v_host_gathering from sessions where profile_id = v_host and ended_at is null;
  assert app.move_evening(v_solo_place) = v_host_gathering, 'a solo evening should become the place''s, not be replaced';
  assert (select place_id from gatherings where id = v_host_gathering) = v_solo_place, 'the evening now has the place';

  -- Back into an evening you already left tonight: refused, not stitched.
  v_failed := false;
  begin
    perform app.move_evening(v_place);
  exception when others then v_failed := true;
  end;
  assert v_failed, 'rejoining an evening you ended tonight must be refused, not merged';

  -- No live evening: nothing to move.
  perform app.end_session(null);
  v_failed := false;
  begin
    perform app.move_evening(v_place);
  exception when others then v_failed := true;
  end;
  assert v_failed, 'with nothing running there is nothing to move';

  perform auth.logout();
  raise notice 'PASS 16  scanning in mid-evening joins the evening already there, start time kept';
end $$;

-- ============================================================ 17
-- Invitations. Alex invites a guest to the Porch by message. Accepting makes
-- the guest one of the Porch's people and STARTS NOTHING — a link opened on a
-- Tuesday is not someone sitting at the table.

do $$
declare
  v_alex   uuid := '99999999-9999-9999-9999-999999999991';
  v_guest  uuid := '99999999-9999-9999-9999-999999999992';
  v_third  uuid := '99999999-9999-9999-9999-999999999993';
  v_stray  uuid := '99999999-9999-9999-9999-999999999994';
  v_place uuid; v_token text; v_row record; v_failed boolean; v_sessions int;
begin
  insert into auth.users (id, email) values (v_alex, 'inviter@example.test'), (v_guest, 'invited@example.test'),
                                            (v_third, 'forwarded@example.test'), (v_stray, 'stray@example.test');
  insert into profiles (id, display_name) values (v_alex, 'Alex'), (v_guest, 'Guest'),
                                                 (v_third, 'Third'), (v_stray, 'Stray');

  perform auth.login(v_alex);
  v_place := app.create_place('warm-porch', 'a-card-on-the-porch-secret', 'The Porch');
  v_token := app.create_invite(v_place);
  assert length(v_token) >= 20, 'the token should be long and random';
  assert not exists (select 1 from invites where token_hash = v_token),
    'only the hash may be stored';

  -- Someone who isn't one of the Porch's people can't bring anyone in.
  perform auth.login(v_stray);
  v_failed := false;
  begin perform app.create_invite(v_place); exception when others then v_failed := true; end;
  assert v_failed, 'a non-member must not be able to invite to a place';

  perform auth.login(v_guest);
  select * into v_row from app.accept_invite(v_token);
  assert v_row.place_id = v_place, 'accepting should land in the Porch';
  assert v_row.place_name = 'The Porch' and v_row.invited_by = 'Alex',
    format('the welcome needs the place and who asked, got %s / %s', v_row.place_name, v_row.invited_by);
  assert exists (select 1 from place_people where place_id = v_place and profile_id = v_guest and left_at is null),
    'the guest must now be one of the Porch''s people';
  select count(*) into v_sessions from sessions where profile_id = v_guest;
  assert v_sessions = 0, 'accepting an invite must not start an evening';

  -- Forwarded to a family group: still good within the week.
  perform auth.login(v_third);
  perform app.accept_invite(v_token);
  assert (select uses from invites where place_id = v_place) = 2, 'both uses should be counted';

  -- A wrong token, and an expired one, are refused.
  v_failed := false;
  begin perform app.accept_invite('not-a-real-token-at-all'); exception when others then v_failed := true; end;
  assert v_failed, 'a made-up token must be refused';

  update invites set expires_at = now() - interval '1 minute' where place_id = v_place;
  perform auth.login(v_stray);
  v_failed := false;
  begin perform app.accept_invite(v_token); exception when others then v_failed := true; end;
  assert v_failed, 'an expired invite must be refused';
  assert not exists (select 1 from place_people where place_id = v_place and profile_id = v_stray),
    'and must not have let anyone in';

  -- Clients never touch the table itself.
  perform auth.logout();
  set local role authenticated;
  v_failed := false;
  begin perform 1 from invites limit 1; exception when insufficient_privilege then v_failed := true; end;
  reset role;
  assert v_failed, 'invites must not be readable by clients';

  raise notice 'PASS 17  an invite joins the place and starts nothing; expired, forged and non-member invites refused';
end $$;

-- ============================================================ 18
-- Company. Home keeps offering an invite until someone else shares one of
-- your places. The answer is a single boolean — never who, never how many.

do $$
declare
  v_lone  uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  v_other uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2';
  v_place uuid; v_token text;
begin
  insert into auth.users (id, email) values (v_lone, 'lone@example.test'), (v_other, 'other@example.test');
  insert into profiles (id, display_name) values (v_lone, 'Lone'), (v_other, 'Other');

  perform auth.login(v_lone);
  assert not app.has_company(), 'no places, no company';
  v_place := app.create_place('lone-table', 'a-card-on-the-lone-table', 'The Lone Table');
  assert not app.has_company(), 'a place of your own is not company';
  v_token := app.create_invite(v_place);

  perform auth.login(v_other);
  perform app.accept_invite(v_token);

  perform auth.login(v_lone);
  assert app.has_company(), 'someone else in your place is company';

  -- They leave: on your own again, and the offer comes back.
  update place_people set left_at = now() where place_id = v_place and profile_id = v_other;
  assert not app.has_company(), 'someone who left is not company';

  perform auth.logout();
  raise notice 'PASS 18  company is one boolean: someone else, still there, in a place of yours';
end $$;

-- ============================================================ FINDING 19
-- Proximity (0010). One phone already down at a table, another across it with
-- nothing to scan. What travels between them is a key that dies with the
-- evening — never a place id, which would outlive it by years.

do $$
declare
  v_host  uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  v_guest uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';
  v_place uuid; v_key text; v_stale text; v_row record; v_failed boolean := false;
  v_gathering uuid; v_sessions int;
begin
  insert into auth.users (id, email) values (v_host, 'host@example.test'), (v_guest, 'guest@example.test');
  insert into profiles (id, display_name) values (v_host, 'Host'), (v_guest, 'Guest');

  -- Nothing running: nothing to advertise, and NOT an error — the phone asks
  -- whenever the radio wants a key and shouldn't have to know the answer.
  perform auth.login(v_host);
  assert app.open_nearby() is null, 'with no evening running there is nothing to advertise';

  -- A placeless evening stays off the radio: joining one would make you one
  -- of the people of a place that doesn't exist.
  perform app.start_or_join(null, 'app', 'UTC');
  assert app.open_nearby() is null, 'a placeless evening must not be findable';
  perform app.end_session(null);

  v_place := app.create_place('host-table', 'a-card-on-the-host-table', 'The Host Table');
  perform app.start_or_join(v_place, 'app', 'UTC');
  v_key := app.open_nearby();
  assert v_key is not null, 'an evening at a place should be findable';
  assert not exists (select 1 from nearby_keys where token_hash = v_key),
    'the key itself must never be stored, only its hash';

  -- The host is already at the table: there is nothing to offer them.
  assert not exists (select 1 from app.nearby_offer(v_key)),
    'no offer to someone already in the evening';

  perform auth.login(v_guest);
  select * into v_row from app.nearby_offer(v_key);
  assert v_row.gathering is not null, 'the guest should be offered the evening';
  assert v_row.people = 1, format('one phone down so far, got %s', v_row.people);

  -- Everything the offer does NOT carry, asserted at the shape of the
  -- function rather than at one call of it. The guest has not joined
  -- anything yet: a place id in here would be a way into that house that
  -- outlives the evening by years, and a name would be someone else's to
  -- give. Adding either breaks this line on purpose.
  assert (select proargnames from pg_proc
           where proname = 'nearby_offer' and pronamespace = 'app'::regnamespace)
         = array['p_token', 'gathering', 'people', 'since'],
    'the offer must carry the evening, the count and the time — nothing else';

  v_gathering := app.join_nearby(v_key, 'UTC');
  assert v_gathering = v_row.gathering, 'joining should land in the evening that was offered';
  select count(*) into v_sessions from sessions where gathering_id = v_gathering;
  assert v_sessions = 2, format('expected two phones down, got %s', v_sessions);
  assert exists (select 1 from place_people where place_id = v_place and profile_id = v_guest),
    'joining over the air makes you one of the place''s people, as a card does';
  assert (select source from sessions where gathering_id = v_gathering and profile_id = v_guest)
         = 'nearby', 'the evening should record how it was joined';

  -- The key is spent on the evening, not on the guest: a second phone may use
  -- the same one, which is the five-people-at-a-table case.
  perform auth.logout();
  perform auth.login('44444444-4444-4444-4444-444444444444');
  assert exists (select 1 from app.nearby_offer(v_key)), 'one key, several phones';
  perform auth.logout();

  -- The host picks their phone up first. The evening is the TABLE'S, not
  -- theirs: the guest is still down, so it is still happening and still
  -- findable.
  perform auth.login(v_host);
  perform app.end_session(null);
  perform auth.login('44444444-4444-4444-4444-444444444444');
  assert exists (select 1 from app.nearby_offer(v_key)),
    'an evening someone is still sitting in is still open to join';

  -- And it dies with the evening. This is the whole reason a key exists
  -- rather than a place id.
  perform auth.login(v_guest);
  perform app.end_session(null);
  perform auth.login('44444444-4444-4444-4444-444444444444');
  assert not exists (select 1 from app.nearby_offer(v_key)), 'a key must not outlive the evening';
  begin perform app.join_nearby(v_key, 'UTC'); exception when others then v_failed := true; end;
  assert v_failed, 'joining an evening that has ended must be refused';

  -- A forged key resolves to nothing.
  assert not exists (select 1 from app.nearby_offer('not-a-real-key-at-all')),
    'a forged key must offer nothing';

  -- Expiry, the backstop for an evening that was never closed.
  perform auth.login(v_host);
  perform app.start_or_join(v_place, 'app', 'UTC');
  v_stale := app.open_nearby();
  update nearby_keys set expires_at = now() - interval '1 minute'
   where token_hash = encode(extensions.digest(v_stale, 'sha256'), 'hex');
  perform auth.login('44444444-4444-4444-4444-444444444444');
  assert not exists (select 1 from app.nearby_offer(v_stale)), 'an expired key must offer nothing';

  -- Nobody reads this table but the functions. Asserted as a privilege
  -- rather than as a failed read, because the harness runs as the owner and
  -- would be let through either way.
  assert not has_table_privilege('authenticated', 'public.nearby_keys', 'select'),
    'nearby keys must not be readable by a client';
  assert not has_table_privilege('anon', 'public.nearby_keys', 'select'),
    'nearby keys must not be readable by anon';

  perform auth.logout();
  raise notice 'PASS 19  a key over the air joins the evening, and is worthless once it ends';
end $$;

-- The guest who was already having an evening of their own: the table they
-- walk up to takes it over rather than starting a second one (0007).
do $$
declare
  v_host  uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3';
  v_guest uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4';
  v_place uuid; v_key text; v_was uuid; v_now uuid; v_started timestamptz;
begin
  insert into auth.users (id, email) values (v_host, 'host2@example.test'), (v_guest, 'guest2@example.test');
  insert into profiles (id, display_name) values (v_host, 'Host2'), (v_guest, 'Guest2');

  perform auth.login(v_host);
  v_place := app.create_place('host-porch', 'a-card-on-the-host-porch', 'The Host Porch');
  perform app.start_or_join(v_place, 'app', 'UTC');
  v_key := app.open_nearby();

  -- Their own evening, started before they walked in.
  perform auth.login(v_guest);
  perform app.start_or_join(null, 'app', 'UTC');
  select gathering_id, started_at into v_was, v_started
    from sessions where profile_id = v_guest and ended_at is null;

  v_now := app.join_nearby(v_key, 'UTC');
  assert v_now <> v_was, 'the guest should have moved to the host''s evening';
  assert (select count(*) from sessions where profile_id = v_guest and ended_at is null) = 1,
    'one live session per person, still';
  assert (select started_at from sessions where profile_id = v_guest and ended_at is null) = v_started,
    'moving an evening must not change what it started at, or what it counts';

  perform auth.logout();
  raise notice 'PASS 20  an evening of your own moves to the table rather than splitting it';
end $$;

-- ============================================================ 21
-- Your evenings, all of them (0011). The end of an evening says "27 of them,
-- since June" — distinct qualifying dates, your own only, and a number that
-- only goes up.

do $$
declare
  v_me    uuid := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1';
  v_other uuid := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee2';
  r record;
begin
  insert into auth.users (id, email) values (v_me, 'counted@example.test'), (v_other, 'elsewhere@example.test');
  insert into profiles (id, display_name) values (v_me, 'Counted'), (v_other, 'Elsewhere');

  perform auth.login(v_me);
  select * into r from app.my_evenings();
  assert r.evenings = 0 and r.first_evening is null, 'nothing yet is zero, with no first evening';

  -- Two on the same day are one evening; a short one is kept, not counted.
  perform app.record_retroactive('2026-06-03 19:00+00', '2026-06-03 20:00+00', 'UTC');
  perform app.record_retroactive('2026-06-03 21:00+00', '2026-06-03 22:30+00', 'UTC');
  perform app.record_retroactive('2026-06-10 19:00+00', '2026-06-10 19:10+00', 'UTC');
  perform app.record_retroactive('2026-07-01 19:00+00', '2026-07-01 19:40+00', 'UTC');

  -- Someone else's evenings are theirs.
  perform auth.login(v_other);
  perform app.record_retroactive('2026-05-01 19:00+00', '2026-05-01 21:00+00', 'UTC');

  perform auth.login(v_me);
  select * into r from public.my_evenings();
  assert r.evenings = 2, format('expected 2 evenings, found %s', r.evenings);
  assert r.first_evening = '2026-06-03', format('first evening should be 2026-06-03, was %s', r.first_evening);

  perform auth.logout();
  raise notice 'PASS 21  your evenings: distinct qualifying dates, your own, from the first';
end $$;


-- ============================================================ 22
-- An evening you didn't start is still only an evening (0012). Retroactive
-- credit was capped by nothing, and screen 18 offered nine hours of sleep.

do $$
declare
  v_me uuid := 'ffffffff-ffff-ffff-ffff-fffffffffff1';
  r record; v_cap integer;
begin
  insert into auth.users (id, email) values (v_me, 'slept@example.test');
  insert into profiles (id, display_name) values (v_me, 'Slept');
  perform auth.login(v_me);
  v_cap := app.auto_close_minutes();

  -- The night from the TestFlight screenshot: 9:42pm to 6:46am.
  perform app.record_retroactive('2026-09-22 21:42+00', '2026-09-23 06:46+00', 'UTC');
  select duration_minutes, started_at, ended_at, qualifying into r
    from sessions where profile_id = v_me;

  assert r.duration_minutes = v_cap,
    format('nine hours should be credited at the cap of %s, got %s', v_cap, r.duration_minutes);
  assert r.ended_at = r.started_at + make_interval(mins => v_cap),
    'the timestamps must agree with the minutes — one evening, one answer';
  assert r.qualifying, 'it still counts';

  -- The gathering it sits in says the same thing.
  assert (select g.ended_at from gatherings g
           join sessions s on s.gathering_id = g.id
          where s.profile_id = v_me) = r.ended_at,
    'the gathering and the session must end at the same moment';

  -- An ordinary forgotten evening is untouched.
  perform app.record_retroactive('2026-09-20 19:30+00', '2026-09-20 21:15+00', 'UTC');
  assert (select duration_minutes from sessions
           where profile_id = v_me and local_date = '2026-09-20') = 105,
    'a real evening is credited exactly as it happened';

  perform auth.logout();
  raise notice 'PASS 22  retroactive credit is capped like auto-close, and agrees with its own clock';
end $$;

do $$ begin raise notice '--- all assertions held ---'; end $$;
