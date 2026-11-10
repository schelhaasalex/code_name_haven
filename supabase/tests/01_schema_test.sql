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
  assert v_row.stage = 'on its way', format('stage was %s', v_row.stage);
  assert v_row.live_now = false, 'gathering should have closed when the last person left';
  raise notice 'PASS  2  1 evening, wall clock % min, person % min',
    v_row.wall_clock_minutes, v_row.person_minutes;
end $$;

-- ============================================================ FINDING 3
-- Visibility. Screen 10 promises the people you dock with never see how often
-- you weren't there. Other people's session rows must be unreadable.

do $$
declare v_mine int; v_profiles int; v_members int; v_cols int;
begin
  set local role authenticated;
  perform auth.login('22222222-2222-2222-2222-222222222222');

  select count(*) into v_mine from sessions;
  assert v_mine = 1, format('Maya should see only her own session, saw %s', v_mine);

  select count(*) into v_profiles from profiles;
  assert v_profiles = 1, format('Maya should see only her own profile, saw %s', v_profiles);

  -- But co-presence still works, through the aggregate: a number, and
  -- nothing that could be enumerated (0023).
  v_members := public.gathering_count((select gathering_id from sessions limit 1));
  assert v_members = 3, format('gathering_count should be 3, got %s', v_members);

  reset role;
  select count(*) into v_cols
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'gathering_count'
     and p.prorettype = 'integer'::regtype and not p.proretset;
  assert v_cols = 1, 'gathering_count returns one integer, never rows';
  assert to_regproc('public.gathering_members') is null,
    'the roster that returned everyone''s id and name is gone';
  raise notice 'PASS  3  own rows only (1 session, 1 profile), co-presence is a count of 3';
end $$;

-- A stranger must not be able to read a gathering they were not in.
do $$
declare v_failed boolean := false; v_gathering uuid;
begin
  select id into v_gathering from gatherings limit 1;
  set local role authenticated;
  perform auth.login('00000000-0000-0000-0000-0000000000ff');
  begin
    perform app.gathering_count(v_gathering);
  exception when others then
    v_failed := true;
  end;
  reset role;
  assert v_failed, 'a non-member must not count a gathering';
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

-- ============================================================ FINDING 9
-- The stage ladder only ever moves forward, and the thresholds are the box's
-- (0022): broken in at a week, settled in at a month, seasoned at a hundred
-- days, part of the house at a year.

do $$
begin
  assert app.place_stage(0)   = 'on its way';
  assert app.place_stage(6)   = 'on its way';
  assert app.place_stage(7)   = 'broken in';
  assert app.place_stage(29)  = 'broken in';
  assert app.place_stage(30)  = 'settled in';
  assert app.place_stage(99)  = 'settled in';
  assert app.place_stage(100) = 'seasoned';
  assert app.place_stage(364) = 'seasoned';
  assert app.place_stage(365) = 'part of the house';
  assert app.place_stage(5000) = 'part of the house';
  raise notice 'PASS  9  stage thresholds are the box''s';
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

-- ============================================================ THE CLIENT API
-- 0005 exists because PostgREST only serves exposed schemas, and `app` is not
-- one: every RPC would have 404'd. The failure reads like a missing function
-- rather than a config gap, so it is asserted rather than remembered.

do $$
declare v_missing text; v_wrapped int; v_anon int;
begin
  for v_missing in
    select name from unnest(array[
      'start_or_join', 'end_session', 'gathering_count', 'place_summary',
      'my_evenings', 'dock_place', 'save_activity_token', 'save_live_activity',
      'delete_my_account', 'note', 'box_code']) as name
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
  assert v_wrapped = 11, format('expected 11 callable wrappers, found %s', v_wrapped);

  -- Every way into an evening but the box is gone, not merely unused (0024):
  -- each was still callable, and retroactive credit could add evenings
  -- nobody spent at a box to its totals.
  for v_missing in
    select name from unnest(array[
      'record_retroactive', 'move_evening', 'create_invite', 'accept_invite',
      'has_company', 'open_nearby', 'nearby_offer', 'join_nearby', 'my_rhythm',
      'name_somewhere', 'merge_places', 'create_place', 'resolve_place',
      'gathering_members']) as name
    where exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = name)
  loop
    assert false, format('public.%s should be gone', v_missing);
  end loop;
  assert to_regclass('public.invites') is null and to_regclass('public.nearby_keys') is null,
    'invites and over-the-air keys should be gone';

  -- The scheduler's job is not a client's to call: nine hours of
  -- phone-on-the-side becoming 180 minutes has to happen TO you, not by you.
  assert not has_function_privilege('authenticated', 'app.auto_close_stale()', 'execute'),
    'auto_close_stale must not be callable by a phone';

  -- anon holds nothing, anywhere. Finding 13 was this being untrue.
  select count(*) into v_anon
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute');
  assert v_anon = 0, format('anon can execute %s functions in public', v_anon);

  raise notice 'PASS 12  ten wrappers callable by authenticated, none by anon, no way in but the box';
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

-- ============================================================ 21
-- Your evenings, all of them (0011). The end of an evening says "27 of them,
-- since June" — distinct qualifying dates, your own only, and a number that
-- only goes up.

-- An evening already over, at no box, as the database would hold it. Written
-- directly: the only way into an evening now is a phone in a box, in real time.
create function pg_temp.evening(p_who uuid, p_from timestamptz, p_minutes int)
returns void language sql as $$
  with g as (
    insert into gatherings (started_by, started_at, ended_at)
    values (p_who, p_from, p_from + make_interval(mins => p_minutes))
    returning id)
  insert into sessions (profile_id, gathering_id, started_at, ended_at,
                        duration_minutes, local_date, qualifying, source)
  select p_who, g.id, p_from, p_from + make_interval(mins => p_minutes),
         p_minutes, (p_from at time zone 'UTC')::date, p_minutes >= 15, 'tag'
    from g
$$;

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
  perform pg_temp.evening(v_me, '2026-06-03 19:00+00', 60);
  perform pg_temp.evening(v_me, '2026-06-03 21:00+00', 90);
  perform pg_temp.evening(v_me, '2026-06-10 19:00+00', 10);
  perform pg_temp.evening(v_me, '2026-07-01 19:00+00', 40);

  -- Someone else's evenings are theirs.
  perform pg_temp.evening(v_other, '2026-05-01 19:00+00', 120);

  perform auth.login(v_me);
  select * into r from public.my_evenings();
  assert r.evenings = 2, format('expected 2 evenings, found %s', r.evenings);
  assert r.first_evening = '2026-06-03', format('first evening should be 2026-06-03, was %s', r.first_evening);

  perform auth.logout();
  raise notice 'PASS 21  your evenings: distinct qualifying dates, your own, from the first';
end $$;

-- ============================================================ 23
-- A box is a place whose secret was written before anyone owned it (0013).
-- The first phone set into it makes the place; everyone after lands in it —
-- including someone who did it in the same second, which the unique secret
-- turns from two places into one.

do $$
declare
  v_first  uuid := 'abababab-abab-abab-abab-ababababab01';
  v_second uuid := 'abababab-abab-abab-abab-ababababab02';
  v_box    uuid; v_again uuid; v_taken uuid;
begin
  insert into auth.users (id, email) values
    (v_first, 'first-in@example.test'), (v_second, 'second-in@example.test');
  insert into profiles (id, display_name) values (v_first, 'First'), (v_second, 'Second');

  perform auth.login(v_first);
  v_box := app.dock_place('a-box-secret-from-the-factory', 'still-heron');
  assert v_box is not null, 'the first phone into a new box makes its place';
  assert (select name from places where id = v_box) is null,
    'a box arrives unnamed — the people at it get to say what it is';
  assert exists (select 1 from place_people where place_id = v_box and profile_id = v_first),
    'whoever made it is one of its people';

  perform auth.login(v_second);
  v_again := app.dock_place('a-box-secret-from-the-factory', 'calm-finch');
  assert v_again = v_box, 'the second phone lands in the same place, not a new one';
  assert (select count(*) from places
           where join_secret_hash = encode(extensions.digest('a-box-secret-from-the-factory', 'sha256'), 'hex')) = 1,
    'one box, one place';

  -- Losing the race at the insert — the other phone got there between the
  -- lookup and the write — is the unique secret's job, not the lookup's.
  begin
    perform app.create_place('slow-moth', 'a-box-secret-from-the-factory', null);
    assert false, 'a second place with the same secret must be refused';
  exception when unique_violation then null;
  end;

  -- A handle someone has already drawn is "ask again", never an error.
  v_taken := app.dock_place('a-different-box-secret', 'still-heron');
  assert v_taken is null, 'a taken handle comes back as null, for the phone to try another';
  assert not exists (select 1 from places
                      where join_secret_hash = encode(extensions.digest('a-different-box-secret', 'sha256'), 'hex')),
    'and nothing is left half-made';

  perform auth.logout();
  raise notice 'PASS 23  a box makes its place once, and everyone set into it lands there';
end $$;

-- ============================================================ 24
-- Stepping out and coming back (0014). Someone at the box left after a
-- minute, and when their phone went back in, start_or_join found their ended
-- row, called it a success, and started nothing — the evening was still open
-- because someone else was in it. Coming back is a new stretch: the time away
-- isn't credited, the person isn't counted twice, and the stretches together
-- decide whether the evening counted.

do $$
declare
  v_here   uuid := 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcd01';
  v_there  uuid := 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcd02';
  v_place  uuid; v_other uuid;
  v_first  uuid; v_back uuid; v_again uuid; v_gathering uuid;
  v_rows   integer; v_people integer; r record;
begin
  insert into auth.users (id, email) values
    (v_here, 'stepped-out@example.test'), (v_there, 'stayed@example.test');
  insert into profiles (id, display_name) values (v_here, 'Stepped'), (v_there, 'Stayed');

  perform auth.login(v_there);
  v_place := app.create_place('near-moth', 'rejoin-secret', null);
  perform app.start_or_join(v_place, 'tag', 'UTC');

  perform auth.login(v_here);
  insert into place_people (place_id, profile_id) values (v_place, v_here);
  v_first := app.start_or_join(v_place, 'tag', 'UTC');
  select gathering_id into v_gathering from sessions where id = v_first;

  -- A first stretch of ten minutes, then out.
  update sessions set started_at = now() - interval '10 minutes' where id = v_first;
  perform app.end_session(v_first);
  assert not (select qualifying from sessions where id = v_first),
    'ten minutes on its own is not an evening yet';

  -- Back in, while the other person is still there.
  v_back := app.start_or_join(v_place, 'tag', 'UTC');
  assert v_back <> v_first, 'coming back is a new stretch, not the old one handed back';
  assert (select ended_at is null from sessions where id = v_back), 'and it is running';
  assert (select gathering_id from sessions where id = v_back) = v_gathering,
    'in the same evening as everyone else';

  -- A second tap while running is still the same stretch.
  v_again := app.start_or_join(v_place, 'tag', 'UTC');
  assert v_again = v_back, 'two taps are one stretch';

  -- Two people, however many stretches.
  v_rows := app.gathering_count(v_gathering);
  assert v_rows = 2, format('two people in the evening, counted %s', v_rows);

  -- Another ten minutes: twenty in all, so the evening counted — both stretches.
  update sessions set started_at = now() - interval '10 minutes' where id = v_back;
  perform app.end_session(v_back);
  assert (select bool_and(qualifying) from sessions
           where gathering_id = v_gathering and profile_id = v_here),
    'two stretches of ten make an evening, and both count toward it';
  assert (select sum(duration_minutes) from sessions
           where gathering_id = v_gathering and profile_id = v_here) = 20,
    'and the time away is not credited';

  perform auth.logout();
  raise notice 'PASS 24  stepping out and coming back is a new stretch, counted once';
end $$;

-- ============================================================ 25
-- A Live Activity the server starts (0015). The phone hands over a token that
-- can put something on its lock screen; nobody may read one, a phone may only
-- ever file its own, and a device that changes hands changes owner.

do $$
declare
  v_a uuid := 'efefefef-efef-efef-efef-efefefefef01';
  v_b uuid := 'efefefef-efef-efef-efef-efefefefef02';
  v_tok text := repeat('ab', 32);
  v_failed boolean;
begin
  insert into auth.users (id, email) values (v_a, 'tokens-a@example.test'), (v_b, 'tokens-b@example.test');
  insert into profiles (id, display_name) values (v_a, 'A'), (v_b, 'B');

  perform auth.login(v_a);
  perform app.save_activity_token(upper(v_tok), 'production');
  assert (select profile_id from activity_tokens where token = v_tok) = v_a,
    'a phone files its own token, stored lowercase whatever it sent';

  -- The same device, signed in as someone else now.
  perform auth.login(v_b);
  perform app.save_activity_token(v_tok, 'sandbox');
  assert (select profile_id from activity_tokens where token = v_tok) = v_b, 'it moves to whoever has it now';
  assert (select environment from activity_tokens where token = v_tok) = 'sandbox', 'with its environment';
  assert (select count(*) from activity_tokens) = 1, 'one device, one row';

  v_failed := false;
  begin perform app.save_activity_token(v_tok, 'staging'); exception when check_violation then v_failed := true; end;
  assert v_failed, 'only Apple''s two environments';

  v_failed := false;
  begin perform app.save_activity_token('not a token', 'production'); exception when check_violation then v_failed := true; end;
  assert v_failed, 'a token is hex, nothing else';

  assert not has_table_privilege('authenticated', 'public.activity_tokens', 'select'),
    'no phone reads anyone''s tokens, its own included';
  assert not has_table_privilege('anon', 'public.activity_tokens', 'select'), 'nor does anyone signed out';

  perform auth.logout();
  v_failed := false;
  begin perform app.save_activity_token(v_tok, 'production'); exception when others then v_failed := true; end;
  assert v_failed, 'signed out, nothing is filed';

  raise notice 'PASS 25  a phone files its own Live Activity token, and nobody reads one';
end $$;

-- ============================================================ 26
-- The evening charges (0016). Each running Live Activity is filed with its
-- own token; once a minute claim_charges hands back what each should show
-- that it isn't showing yet: the next segment, a light for someone who
-- joined, or 'end' for an evening the person has left. Each step once.

do $$
declare
  v_a uuid := 'abababab-1616-1616-1616-161616161601';
  v_b uuid := 'abababab-1616-1616-1616-161616161602';
  v_tok text := repeat('cd', 32);
  v_place uuid; v_session uuid; v_theirs uuid; v_gathering uuid;
  v_start double precision;
  v_failed boolean; r record; v_n integer;
begin
  insert into auth.users (id, email) values (v_a, 'charge-a@example.test'), (v_b, 'charge-b@example.test');
  insert into profiles (id, display_name) values (v_a, 'A'), (v_b, 'B');

  assert app.charge_stage(0) = 0 and app.charge_stage(14.9) = 0, 'nothing full before fifteen minutes';
  assert app.charge_stage(15) = 1 and app.charge_stage(30) = 2, 'a segment at fifteen, another at thirty';
  assert app.charge_stage(60) = 3 and app.charge_stage(90) = 4, 'three at the hour, four at an hour and a half';
  assert app.charge_stage(600) = 4, 'and then it holds';

  perform auth.login(v_a);
  v_place := app.create_place('charge-moth', 'charge-secret', null);
  v_session := app.start_or_join(v_place, 'tag', 'UTC');
  select gathering_id into v_gathering from sessions where id = v_session;

  -- Started ten minutes ago, in ActivityKit's seconds since 2001.
  v_start := extract(epoch from now() - interval '10 minutes') - 978307200;
  perform app.save_live_activity(upper(v_tok), v_gathering, 'production',
    jsonb_build_object('startedAt', v_start, 'memberCount', 1, 'placeName', 'Kitchen', 'stage', 0)::text);
  assert (select profile_id from live_activities where token = v_tok) = v_a, 'filed as yours, lowercase';

  perform auth.logout();
  select count(*) into v_n from app.claim_charges();
  assert v_n = 0, 'nothing new to show at ten minutes, alone';

  -- Someone else puts their phone down.
  perform auth.login(v_b);
  insert into place_people (place_id, profile_id) values (v_place, v_b);
  v_theirs := app.start_or_join(v_place, 'tag', 'UTC');
  perform auth.logout();

  select * into r from app.claim_charges();
  assert r.event = 'update' and (r.state ->> 'memberCount')::int = 2, 'a light joins the ring';
  assert (r.state ->> 'stage')::int = 0, 'the stage is still the first';
  assert (r.state ->> 'startedAt')::double precision = v_start and r.state ->> 'placeName' = 'Kitchen',
    'and everything else is what the phone wrote';
  select count(*) into v_n from app.claim_charges();
  assert v_n = 0, 'once: the next minute has nothing new';

  -- Sixty-one minutes in: one push carries every step since.
  select count(*) into v_n from app.claim_charges(now() + interval '51 minutes');
  select stage_sent into v_n from live_activities where token = v_tok;
  assert v_n = 3, 'three segments at the hour, in one push';

  -- B goes home. The light stays: the count goes up, never down.
  perform auth.login(v_b);
  perform app.end_session(v_theirs);
  perform auth.logout();
  select count(*) into v_n from app.claim_charges(now() + interval '52 minutes');
  assert v_n = 0, 'someone leaving takes no light away';

  -- A ends the evening.
  perform auth.login(v_a);
  perform app.end_session(v_session);
  perform auth.logout();
  select * into r from app.claim_charges();
  assert r.event = 'end', 'an evening you have left ends its Live Activity';
  assert not exists (select 1 from live_activities where token = v_tok), 'and is forgotten';

  -- Filing needs you to be in the evening.
  perform auth.login(v_b);
  delete from sessions where profile_id = v_b;
  v_failed := false;
  begin
    perform app.save_live_activity(v_tok, v_gathering, 'production', '{"startedAt": 1}');
  exception when others then v_failed := true; end;
  assert v_failed, 'not for an evening you were never in';

  perform auth.login(v_a);
  v_failed := false;
  begin
    perform app.save_live_activity(v_tok, v_gathering, 'production', '{"placeName": "x"}');
  exception when check_violation then v_failed := true; end;
  assert v_failed, 'a state with no start time is refused';

  assert not has_table_privilege('authenticated', 'public.live_activities', 'select'),
    'no phone reads the tokens';
  assert not has_function_privilege('authenticated', 'public.claim_charges(text)', 'execute'),
    'and none can claim the pushes';
  assert has_function_privilege('service_role', 'public.claim_charges(text)', 'execute'),
    'the Edge Function can';

  perform auth.logout();
  raise notice 'PASS 26  the evening charges in four steps, a light per person, each sent once';
end $$;

-- ============================================================ 27
-- Reading a box makes you one of its people (0017). A phone that pairs by the
-- box's code starts no evening, and still has to see the box it paired with.

do $$
declare
  v_maker  uuid := 'b7b7b7b7-b7b7-b7b7-b7b7-b7b7b7b7b701';
  v_reader uuid := 'b7b7b7b7-b7b7-b7b7-b7b7-b7b7b7b7b702';
  v_box    uuid;
begin
  insert into auth.users (id, email) values
    (v_maker, 'maker@example.test'), (v_reader, 'reader@example.test');
  insert into profiles (id) values (v_maker), (v_reader);

  perform auth.login(v_maker);
  v_box := app.dock_place('a-box-read-by-its-code', 'clear-wren');

  perform auth.login(v_reader);
  assert app.dock_place('a-box-read-by-its-code', 'open-pike') = v_box, 'the same box';
  assert exists (select 1 from place_people
                  where place_id = v_box and profile_id = v_reader and left_at is null),
    'reading it is joining it, with no evening';
  assert not exists (select 1 from sessions where profile_id = v_reader), 'and starts nothing';
  assert (select evenings from app.place_summary(v_box)) = 0,
    'so its summary is theirs to read';

  update place_people set left_at = now() where place_id = v_box and profile_id = v_reader;
  perform app.dock_place('a-box-read-by-its-code', 'open-pike');
  assert exists (select 1 from place_people
                  where place_id = v_box and profile_id = v_reader and left_at is null),
    'someone who had left and reads it again is back';
  assert (select count(*) from place_people where place_id = v_box and profile_id = v_reader) = 1,
    'once, not twice';

  perform auth.logout();
  raise notice 'PASS 27  reading a box makes you one of its people, and starts nothing';
end $$;

-- ============================================================ 28
-- Every evening is credited at most the cap, however it ends (0018). A phone
-- left in the box overnight and taken out by hand the next afternoon, before
-- the scheduled close got to it, was credited all seventeen hours — and the
-- box's total counted them too.
do $$
declare
  v_me      uuid := 'b8b8b8b8-b8b8-b8b8-b8b8-b8b8b8b8b801';
  v_box     uuid;
  v_session uuid;
  v_cap     integer := app.auto_close_minutes();
begin
  insert into auth.users (id, email) values (v_me, 'overnight@example.test');
  insert into profiles (id) values (v_me);
  perform auth.login(v_me);
  v_box := app.dock_place('a-box-left-overnight', 'late-heron');
  v_session := app.start_or_join(v_box, 'tag', 'UTC');
  update sessions set started_at = now() - interval '17 hours 45 minutes' where id = v_session;
  update gatherings set started_at = now() - interval '17 hours 45 minutes'
   where id = (select gathering_id from sessions where id = v_session);
  assert app.end_session(v_session) = v_cap, 'ending it by hand credits the cap';
  assert (select duration_minutes from sessions where id = v_session) = v_cap, 'and keeps it';
  assert (select qualifying from sessions where id = v_session), 'and it counts';
  assert (select ended_at from sessions where id = v_session) > now() - interval '1 minute',
    'it ended when it ended';
  assert (select wall_clock_minutes from app.place_summary(v_box)) = v_cap,
    'the box keeps the cap, not the seventeen hours';
  v_session := app.start_or_join(v_box, 'tag', 'UTC');
  update sessions set started_at = now() - interval '50 minutes' where id = v_session;
  update gatherings set started_at = now() - interval '50 minutes'
   where id = (select gathering_id from sessions where id = v_session);
  assert app.end_session(v_session) = 50, 'an evening under the cap is what it was';
  assert (select wall_clock_minutes from app.place_summary(v_box)) = v_cap + 50,
    'and adds what it was';
  perform auth.logout();
  raise notice 'PASS 28  every evening is credited at most the cap, however it ends';
end $$;
-- ============================================================ 29
-- A box's hours are the time someone was in it (0019). Seen on the test box:
-- one phone left in overnight, capped at three hours, and a second that joined
-- the still-open evening for a minute the next afternoon. First in to last
-- out was fifteen hours, nearly all of them empty.
do $$
declare
  v_first  uuid := 'b9b9b9b9-b9b9-b9b9-b9b9-b9b9b9b9b901';
  v_late   uuid := 'b9b9b9b9-b9b9-b9b9-b9b9-b9b9b9b9b902';
  v_box    uuid;
  v_s1     uuid;
  v_s2     uuid;
  v_g      uuid;
  v_cap    integer := app.auto_close_minutes();
begin
  insert into auth.users (id, email) values
    (v_first, 'first@example.test'), (v_late, 'late@example.test');
  insert into profiles (id) values (v_first), (v_late);
  perform auth.login(v_first);
  v_box := app.dock_place('a-box-with-a-gap', 'still-otter');
  v_s1 := app.start_or_join(v_box, 'tag', 'UTC');
  select gathering_id into v_g from sessions where id = v_s1;
  update sessions set started_at = now() - interval '15 hours' where id = v_s1;
  update gatherings set started_at = now() - interval '15 hours' where id = v_g;
  perform auth.login(v_late);
  perform app.dock_place('a-box-with-a-gap', 'still-otter');
  v_s2 := app.start_or_join(v_box, 'tag', 'UTC');
  assert (select gathering_id from sessions where id = v_s2) = v_g, 'the same evening, still open';
  perform app.end_session(v_s2);
  perform auth.login(v_first);
  perform app.end_session(v_s1);
  assert (select wall_clock_minutes from app.place_summary(v_box)) = v_cap,
    'the three hours someone was in, not the fifteen between';

  -- Two together for an hour, and one staying on for another: two hours.
  v_s1 := app.start_or_join(v_box, 'tag', 'UTC');
  select gathering_id into v_g from sessions where id = v_s1;
  update sessions set started_at = now() - interval '2 hours' where id = v_s1;
  update gatherings set started_at = now() - interval '2 hours' where id = v_g;
  perform auth.login(v_late);
  v_s2 := app.start_or_join(v_box, 'tag', 'UTC');
  update sessions set started_at = now() - interval '2 hours' where id = v_s2;
  update sessions set ended_at = now() - interval '1 hour', duration_minutes = 60 where id = v_s2;
  perform auth.login(v_first);
  perform app.end_session(v_s1);
  assert (select wall_clock_minutes from app.place_summary(v_box)) = v_cap + 120,
    'together counts once, and the hour after it too';
  perform auth.logout();
  raise notice 'PASS 29  a box''s hours are the time someone was in it';
end $$;
-- ============================================================ 30
-- Deleting an account deletes the login, and the hours stay (0020). The app
-- used to delete its profile and leave the login behind, and the profile took
-- its evenings with it, so the box's total fell for everyone else.
do $$
declare
  v_leaving uuid := 'babababa-baba-baba-baba-babababa0001';
  v_staying uuid := 'babababa-baba-baba-baba-babababa0002';
  v_box     uuid;
  v_s       uuid;
  v_g       uuid;
  v_live    uuid;
  v_before  integer;
  v_failed  boolean := false;
begin
  insert into auth.users (id, email) values
    (v_leaving, 'leaving@example.test'), (v_staying, 'staying@example.test');
  insert into profiles (id) values (v_leaving), (v_staying);
  perform auth.login(v_leaving);
  v_box := app.dock_place('a-box-someone-leaves', 'calm-lark');
  v_s := app.start_or_join(v_box, 'tag', 'UTC');
  select gathering_id into v_g from sessions where id = v_s;
  update sessions set started_at = now() - interval '1 hour' where id = v_s;
  update gatherings set started_at = now() - interval '1 hour' where id = v_g;
  perform app.end_session(v_s);
  perform auth.login(v_staying);
  perform app.dock_place('a-box-someone-leaves', 'calm-lark');
  v_before := (select wall_clock_minutes from app.place_summary(v_box));
  assert v_before = 60, 'the hour they spent there';

  perform auth.login(v_leaving);
  v_live := app.start_or_join(v_box, 'tag', 'UTC');
  perform app.delete_my_account();
  assert not exists (select 1 from auth.users where id = v_leaving), 'the login is gone';
  assert not exists (select 1 from profiles where id = v_leaving), 'and the profile';
  assert not exists (select 1 from place_people where profile_id = v_leaving), 'and its boxes';
  assert (select ended_at from sessions where id = v_live) is not null, 'its running evening ended first';
  assert (select profile_id from sessions where id = v_s) is null, 'its evenings stay, owned by nobody';

  perform auth.login(v_staying);
  assert (select wall_clock_minutes from app.place_summary(v_box)) = v_before,
    'the box keeps the hour';
  set local role authenticated;
  assert not exists (select 1 from sessions where id = v_s), 'and nobody can read the row';
  reset role;

  perform auth.logout();
  begin
    perform app.delete_my_account();
  exception when others then v_failed := true; end;
  assert v_failed, 'not without an account';
  assert not has_function_privilege('anon', 'public.delete_my_account()', 'execute'), 'anon has no door';
  raise notice 'PASS 30  deleting an account deletes the login, and the hours stay';
end $$;
-- ============================================================ 31
-- What goes wrong is noted, and nobody's phone can read it (0021). A note
-- names only a box its writer belongs to, a phone in a loop can't fill the
-- table, and the pilot's views are out of every client's reach.
do $$
declare
  v_me    uuid := 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcd0001';
  v_other uuid := 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcd0002';
  v_mine  uuid;
  v_theirs uuid;
  v_failed boolean := false;
begin
  insert into auth.users (id, email) values (v_me, 'notes@example.test'), (v_other, 'other@example.test');
  insert into profiles (id) values (v_me), (v_other);
  perform auth.login(v_other);
  v_theirs := app.dock_place('someone-elses-box', 'quiet-heron');
  perform auth.login(v_me);
  v_mine := app.dock_place('a-box-that-notes', 'brisk-wren');

  perform app.note('box_hello', v_mine, '{"boots": 3, "up": 60, "fw": "0.4"}');
  assert (select place_id from events where profile_id = v_me and kind = 'box_hello') = v_mine,
    'a note on my box keeps the box';
  perform app.note('paired', v_theirs);
  assert (select place_id from events where profile_id = v_me and kind = 'paired') is null,
    'a note never names a box I am not in';

  begin
    perform app.note('opened_instagram', v_mine);
  exception when check_violation then v_failed := true; end;
  assert v_failed, 'only the moments on the list';

  for i in 1..20 loop perform app.note('pair_not_heard', v_mine); end loop;
  assert (select count(*) from events where profile_id = v_me and at > now() - interval '1 minute') = 10,
    'ten a minute, and the rest dropped';

  set local role authenticated;
  v_failed := false;
  begin
    perform 1 from events limit 1;
  exception when insufficient_privilege then v_failed := true; end;
  assert v_failed, 'no phone reads the notes';
  v_failed := false;
  begin
    perform 1 from ops.box_health limit 1;
  exception when insufficient_privilege then v_failed := true; end;
  assert v_failed, 'nor the pilot';
  reset role;

  assert (select restarts_7d from ops.box_health where box = 'brisk-wren') = 0, 'one hello is no restart';
  assert not has_function_privilege('anon', 'public.note(text, uuid, jsonb)', 'execute'), 'anon has no door';
  perform auth.logout();
  raise notice 'PASS 31  what goes wrong is noted, and only the pilot reads it';
end $$;
-- ============================================================ 32
-- A lost card (0025). Anyone in a box can make a code a second phone scans
-- as it would the card. A code lasts an hour — and one that has run out must
-- never fall through to dock_place's first-scan path and make a new box.
do $$
declare
  v_in      uuid := 'c0dec0de-c0de-c0de-c0de-c0dec0de0001';
  v_new     uuid := 'c0dec0de-c0de-c0de-c0de-c0dec0de0002';
  v_out     uuid := 'c0dec0de-c0de-c0de-c0de-c0dec0de0003';
  v_late    uuid := 'c0dec0de-c0de-c0de-c0de-c0dec0de0004';
  v_box     uuid;
  v_code    text;
  v_old     text;
  v_places  int;
  v_failed  boolean;
  v_state   text;
begin
  insert into auth.users (id, email) values
    (v_in, 'in@example.test'), (v_new, 'new@example.test'),
    (v_out, 'out@example.test'), (v_late, 'late@example.test');
  insert into profiles (id) values (v_in), (v_new), (v_out), (v_late);

  perform auth.login(v_in);
  v_box := app.dock_place('a-card-that-gets-lost', 'lost-heron');

  -- Someone who was never in it gets no code.
  perform auth.login(v_out);
  v_failed := false;
  begin
    perform app.box_code(v_box);
  exception when insufficient_privilege then v_failed := true; end;
  assert v_failed, 'a stranger gets no code for a box';

  -- A member's code pairs a second phone to the same box, and starts nothing.
  perform auth.login(v_in);
  v_code := app.box_code(v_box);
  assert length(v_code) = 43 and v_code ~ '^[A-Za-z0-9_-]+$',
    format('a code is a card-shaped secret, got %s', v_code);
  assert app.box_code(v_box) <> v_code, 'a fresh code each time';
  assert not exists (select 1 from app.place_codes where code_hash = v_code),
    'only the hash is kept';

  perform auth.login(v_new);
  assert app.dock_place(v_code, 'other-wren') = v_box, 'the code pairs to the same box';
  assert exists (select 1 from place_people
                  where place_id = v_box and profile_id = v_new and left_at is null),
    'and makes them one of its people';
  assert not exists (select 1 from sessions where profile_id = v_new), 'and starts nothing';

  -- Someone who has left gets no code.
  update place_people set left_at = now() where place_id = v_box and profile_id = v_new;
  v_failed := false;
  begin
    perform app.box_code(v_box);
  exception when insufficient_privilege then v_failed := true; end;
  assert v_failed, 'someone who left gets no code';

  -- An hour on, the code pairs no one, and — the trap — makes no box.
  perform auth.login(v_in);
  v_old := app.box_code(v_box);
  update app.place_codes set expires_at = now() - interval '1 second'
   where code_hash = encode(extensions.digest(v_old, 'sha256'), 'hex');
  select count(*) into v_places from places;

  perform auth.login(v_late);
  v_failed := false;
  begin
    perform app.dock_place(v_old, 'stray-wren');
  exception when others then v_failed := true; v_state := sqlstate; end;
  assert v_failed and v_state = 'RC410', format('a code that ran out is refused as RC410, got %s', v_state);
  assert (select count(*) from places) = v_places, 'and no new box is made from it';
  assert not exists (select 1 from place_people where profile_id = v_late), 'nor is anyone added';

  -- The card itself still works after codes have been made.
  assert app.dock_place('a-card-that-gets-lost', 'again-wren') = v_box, 'the card is still the key';

  -- No phone reads the codes, and anon can't make one.
  set local role authenticated;
  v_failed := false;
  begin
    perform 1 from app.place_codes limit 1;
  exception when insufficient_privilege then v_failed := true; end;
  assert v_failed, 'no phone reads the codes';
  reset role;
  assert not has_function_privilege('anon', 'public.box_code(uuid)', 'execute'), 'anon has no door';

  perform auth.logout();
  raise notice 'PASS 32  a lost card: a member''s code pairs for an hour, and never makes a box';
end $$;
do $$ begin raise notice '--- all assertions held ---'; end $$;
