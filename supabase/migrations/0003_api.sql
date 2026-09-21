-- Reclaim — the API surface.
--
-- Clients call these rather than querying tables directly wherever the answer
-- involves anyone else's data. Everything that crosses a person boundary is
-- SECURITY DEFINER and returns an aggregate, which is what keeps the promise on
-- screen 10 ("they see that you were there, never how often you weren't").

-- -------------------------------------------------------------- place stage
-- Named stages, derived from the evening count. They only ever move forward:
-- there is no path in this function that returns a lower stage for a higher
-- count, and nothing anywhere decrements evenings.

create or replace function app.place_stage(p_evenings integer)
returns text language sql immutable as $$
  select case
    when p_evenings >= 50 then 'a landmark'
    when p_evenings >= 20 then 'a reclaim house'
    when p_evenings >= 5  then 'a regular table'
    else 'new here'
  end
$$;

-- ------------------------------------------------------------ resolve a card
-- Takes the long secret out of the tag or QR, follows any merge chain, and
-- returns the place. The hash column is never selectable, so this is the only
-- way in. Merged places keep resolving, which is what stops a merge from
-- bricking a card already printed and stuck to someone's door.

create or replace function app.resolve_place(p_secret text)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare
  v_id   uuid;
  v_next uuid;
  v_hops integer := 0;
begin
  select id into v_id
    from public.places
   where join_secret_hash = encode(extensions.digest(p_secret, 'sha256'), 'hex');

  if v_id is null then
    return null;
  end if;

  loop
    select merged_into into v_next from public.places where id = v_id;
    exit when v_next is null;
    v_id := v_next;
    v_hops := v_hops + 1;
    if v_hops > 16 then
      raise exception 'merge chain too deep for place %', v_id;
    end if;
  end loop;

  return v_id;
end $$;

-- ------------------------------------------------------------ create a place

create or replace function app.create_place(
  p_handle text,
  p_secret text,
  p_name   text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  insert into public.places (name, handle, join_secret_hash, created_by)
  values (p_name, p_handle,
          encode(extensions.digest(p_secret, 'sha256'), 'hex'), v_me)
  returning id into v_id;

  insert into public.place_people (place_id, profile_id) values (v_id, v_me);
  return v_id;
end $$;

-- ------------------------------------------------------------- start or join
-- One entry point for every way a session begins: the app, a tag, a Control
-- Centre control, Siri, a Shortcut.
--
-- An OPEN GATHERING AT THIS PLACE ALWAYS WINS over creating a new one. That is
-- the fix for two people tapping within a couple of seconds of each other; the
-- partial unique index in 0001 makes the losing insert fail, and the handler
-- below turns that failure into a join.

create or replace function app.start_or_join(
  p_place  uuid default null,
  p_source text default 'app',
  p_tz     text default 'UTC')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me        uuid := auth.uid();
  v_gathering uuid;
  v_session   uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  if p_place is not null then
    select id into v_gathering
      from public.gatherings
     where place_id = p_place and ended_at is null
     order by started_at
     limit 1;
  end if;

  if v_gathering is null then
    begin
      insert into public.gatherings (place_id, started_by)
      values (p_place, v_me)
      returning id into v_gathering;
    exception when unique_violation then
      select id into v_gathering
        from public.gatherings
       where place_id = p_place and ended_at is null
       limit 1;
    end;
  end if;

  insert into public.sessions (profile_id, gathering_id, local_date, source)
  values (v_me, v_gathering, (now() at time zone p_tz)::date, p_source)
  on conflict (gathering_id, profile_id) do update set source = excluded.source
  returning id into v_session;

  if p_place is not null then
    insert into public.place_people (place_id, profile_id)
    values (p_place, v_me)
    on conflict (place_id, profile_id) do update set left_at = null;
  end if;

  return v_session;
end $$;

-- ---------------------------------------------------------------- end a session

create or replace function app.end_session(p_session uuid default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_me       uuid := auth.uid();
  v_id       uuid;
  v_gather   uuid;
  v_minutes  integer;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select id into v_id
    from public.sessions
   where profile_id = v_me and ended_at is null
     and (p_session is null or id = p_session)
   limit 1;

  if v_id is null then return null; end if;

  update public.sessions
     set ended_at         = now(),
         duration_minutes = floor(extract(epoch from (now() - started_at)) / 60)::int,
         qualifying       = floor(extract(epoch from (now() - started_at)) / 60)
                              >= app.qualifying_minutes()
   where id = v_id
  returning gathering_id, duration_minutes into v_gather, v_minutes;

  -- Close the gathering once nobody in it is still live, so the place stops
  -- reading as "happening now" and the partial unique index frees up.
  update public.gatherings g
     set ended_at = now()
   where g.id = v_gather
     and g.ended_at is null
     and not exists (select 1 from public.sessions s
                      where s.gathering_id = g.id and s.ended_at is null);

  return v_minutes;
end $$;

-- ------------------------------------------------------------- auto-close
-- Run on a schedule. Credits at the CAP, not at the wall-clock time the phone
-- actually sat there — otherwise the cheapest strategy in the product becomes
-- starting a session and never ending it, and hours reclaimed turns to noise.

create or replace function app.auto_close_stale()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_cap integer := app.auto_close_minutes();
  v_n   integer;
begin
  with closed as (
    update public.sessions
       set ended_at         = started_at + make_interval(mins => v_cap),
           duration_minutes = v_cap,
           qualifying       = v_cap >= app.qualifying_minutes(),
           auto_closed      = true
     where ended_at is null
       and started_at < now() - make_interval(mins => v_cap)
    returning gathering_id
  )
  select count(*) into v_n from closed;

  update public.gatherings g
     set ended_at = now()
   where g.ended_at is null
     and not exists (select 1 from public.sessions s
                      where s.gathering_id = g.id and s.ended_at is null);

  return v_n;
end $$;

-- ------------------------------------------------------- retroactive credit
-- Screen 18. The phone sat still; the user says whether it counted. Always
-- solo and always placeless — nobody was broadcasting, so co-presence cannot
-- be reconstructed after the fact and must not be invented.

create or replace function app.record_retroactive(
  p_started timestamptz,
  p_ended   timestamptz,
  p_tz      text default 'UTC')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me      uuid := auth.uid();
  v_gather  uuid;
  v_id      uuid;
  v_minutes integer;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_ended <= p_started then raise exception 'retroactive session ends before it starts'; end if;

  v_minutes := floor(extract(epoch from (p_ended - p_started)) / 60)::int;

  insert into public.gatherings (place_id, started_by, started_at, ended_at)
  values (null, v_me, p_started, p_ended)
  returning id into v_gather;

  insert into public.sessions (
    profile_id, gathering_id, started_at, ended_at, duration_minutes,
    local_date, qualifying, retroactive, source)
  values (
    v_me, v_gather, p_started, p_ended, v_minutes,
    (p_started at time zone p_tz)::date,
    v_minutes >= app.qualifying_minutes(), true, 'retroactive')
  returning id into v_id;

  return v_id;
end $$;

-- ------------------------------------------------------- who is in the room
-- The ONLY way to learn about another person's session. Returns presence for
-- one gathering you are in, and nothing else — no dates, no history, no counts.

create or replace function app.gathering_members(p_gathering uuid)
returns table (profile_id uuid, display_name text, still_live boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.sessions s
                  where s.gathering_id = p_gathering and s.profile_id = auth.uid())
  then
    raise exception 'not a member of this gathering';
  end if;

  return query
    select s.profile_id, pr.display_name, (s.ended_at is null)
      from public.sessions s
      join public.profiles pr on pr.id = s.profile_id
     where s.gathering_id = p_gathering
     order by s.started_at;
end $$;

-- ------------------------------------------------------ a place's own stats
-- COUNT(DISTINCT local_date) is what makes a five-person dinner one evening
-- rather than five.
--
-- Two different hour numbers, deliberately named apart:
--   wall_clock_minutes — how long the room was gathered. This is what screen 9
--                        shows, and it does not grow with household size.
--   person_minutes     — summed across people. This is the "hours reclaimed"
--                        supporting metric, and it does.

create or replace function app.place_summary(p_place uuid)
returns table (
  evenings           integer,
  wall_clock_minutes integer,
  person_minutes     integer,
  stage              text,
  since              date,
  live_now           boolean)
language plpgsql stable security definer set search_path = '' as $$
declare v_evenings integer;
begin
  if not exists (select 1 from public.place_people pp
                  where pp.place_id = p_place
                    and pp.profile_id = auth.uid()
                    and pp.left_at is null)
  then
    raise exception 'not a member of this place';
  end if;

  select count(distinct s.local_date)
    into v_evenings
    from public.sessions s
    join public.gatherings g on g.id = s.gathering_id
   where g.place_id = p_place and s.qualifying;

  return query
  select
    v_evenings,
    coalesce((
      select sum(floor(extract(epoch from (g.ended_at - g.started_at)) / 60))::int
        from public.gatherings g
       where g.place_id = p_place
         and g.ended_at is not null
         and exists (select 1 from public.sessions s
                      where s.gathering_id = g.id and s.qualifying)), 0),
    coalesce((
      select sum(s.duration_minutes)::int
        from public.sessions s
        join public.gatherings g on g.id = s.gathering_id
       where g.place_id = p_place and s.qualifying), 0),
    app.place_stage(v_evenings),
    (select min(s.local_date) from public.sessions s
       join public.gatherings g on g.id = s.gathering_id
      where g.place_id = p_place and s.qualifying),
    exists (select 1 from public.gatherings g
             where g.place_id = p_place and g.ended_at is null);
end $$;

-- --------------------------------------------------------------- my rhythm
-- A state, not a rank. A run survives a single missed day provided a rest day
-- is still unspent for the ISO week that the gap falls in. The rest day covers
-- the gap; it does not itself count as an evening.
--
-- This is the fiddliest logic in the schema and the piece most worth unit
-- tests. The data is tiny (a few hundred rows per person per year), so a
-- readable loop beats clever window functions.

create or replace function app.my_rhythm()
returns table (
  state                 text,
  current_run_days      integer,
  longest_run_days      integer,
  last_qualifying_date  date,
  rest_day_available    boolean)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_me        uuid := auth.uid();
  v_dates     date[];
  d           date;
  v_prev      date;
  v_run       integer := 0;
  v_best      integer := 0;
  v_forgiven  text[]  := '{}';
  v_week      text;
  v_rest      boolean;
  v_state     text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select coalesce(array_agg(x order by x), '{}')
    into v_dates
    from (select distinct s.local_date as x
            from public.sessions s
           where s.profile_id = v_me and s.qualifying) t;

  if array_length(v_dates, 1) is null then
    return query select 'between'::text, 0, 0, null::date, true;
    return;
  end if;

  foreach d in array v_dates loop
    if v_prev is null then
      v_run := 1;
    elsif d = v_prev + 1 then
      v_run := v_run + 1;
    elsif d = v_prev + 2 then
      v_week := to_char(v_prev + 1, 'IYYY-IW');
      if not (v_week = any(v_forgiven)) then
        v_forgiven := v_forgiven || v_week;
        v_run := v_run + 1;
      else
        v_run := 1;
      end if;
    else
      v_run := 1;
    end if;

    if v_run > v_best then v_best := v_run; end if;
    v_prev := d;
  end loop;

  v_rest := not (to_char(current_date, 'IYYY-IW') = any(v_forgiven));

  if v_prev >= current_date - 1 then
    v_state := 'in_rhythm';
  elsif v_prev = current_date - 2 and v_rest then
    v_state := 'in_rhythm';
  else
    v_state := 'between';
    v_run := 0;
  end if;

  return query select v_state, v_run, v_best, v_prev, v_rest;
end $$;

-- ---------------------------------------------------------- name a Somewhere
-- Screen 17's "Name them" and screen 21. Attaches the caller's placeless
-- gatherings to a newly created place, so history moves with the name.

create or replace function app.name_somewhere(
  p_handle text,
  p_secret text,
  p_name   text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me    uuid := auth.uid();
  v_place uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  v_place := app.create_place(p_handle, p_secret, p_name);

  update public.gatherings g
     set place_id = v_place
   where g.place_id is null
     and g.ended_at is not null
     and exists (select 1 from public.sessions s
                  where s.gathering_id = g.id and s.profile_id = v_me);

  return v_place;
end $$;

-- ------------------------------------------------------------------- merge
-- Two cards that are really one place. The source place is KEPT, with
-- merged_into set, so the tag already stuck to a door keeps resolving.

create or replace function app.merge_places(p_from uuid, p_into uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_from = p_into then raise exception 'cannot merge a place into itself'; end if;

  if not exists (select 1 from public.places
                  where id = p_from and created_by = v_me)
     or not exists (select 1 from public.places
                     where id = p_into and created_by = v_me)
  then
    raise exception 'you can only merge places you own';
  end if;

  -- End anything still open on either side so the one-open-gathering-per-place
  -- index cannot be violated by the repoint below.
  update public.gatherings set ended_at = now()
   where place_id in (p_from, p_into) and ended_at is null;

  update public.gatherings set place_id = p_into where place_id = p_from;

  insert into public.place_people (place_id, profile_id, first_seen_at)
  select p_into, pp.profile_id, pp.first_seen_at
    from public.place_people pp
   where pp.place_id = p_from
  on conflict (place_id, profile_id) do update
    set first_seen_at = least(public.place_people.first_seen_at, excluded.first_seen_at),
        left_at = null;

  update public.places set merged_into = p_into where id = p_from;
end $$;

-- --------------------------------------------------------------- privileges

revoke all on function
  app.resolve_place(text), app.create_place(text, text, text),
  app.start_or_join(uuid, text, text), app.end_session(uuid),
  app.auto_close_stale(), app.record_retroactive(timestamptz, timestamptz, text),
  app.gathering_members(uuid), app.place_summary(uuid), app.my_rhythm(),
  app.name_somewhere(text, text, text), app.merge_places(uuid, uuid),
  app.place_stage(integer)
from public;

grant execute on function
  app.resolve_place(text), app.create_place(text, text, text),
  app.start_or_join(uuid, text, text), app.end_session(uuid),
  app.record_retroactive(timestamptz, timestamptz, text),
  app.gathering_members(uuid), app.place_summary(uuid), app.my_rhythm(),
  app.name_somewhere(text, text, text), app.merge_places(uuid, uuid),
  app.place_stage(integer)
to authenticated;

-- auto_close_stale is deliberately NOT granted to authenticated: it runs from a
-- scheduler, not from a client.
