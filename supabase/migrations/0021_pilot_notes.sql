-- Reclaim — what goes wrong, noted; and the pilot, added up.
--
-- Evenings are already recorded. What wasn't is the moment setup or the box
-- fails: a card that didn't go through, a box never heard while pairing, the
-- camera or Bluetooth refused, the lock screen ring turned off, a box that
-- restarted. With boxes in other people's homes, that otherwise arrives as
-- "it stopped working", weeks later.
--
-- A phone notes one of a fixed list of moments, against a box, with a small
-- detail. It can't read any of it back — nobody's client can — and it can't
-- note more than a few a minute. Settings says this happens.
--
-- The `ops` schema adds the pilot up for whoever runs it, from the SQL Editor:
-- per box, never per person. It isn't exposed to the API and no client role
-- can use it.

create table public.events (
  id         bigint generated always as identity primary key,
  at         timestamptz not null default now(),
  profile_id uuid references public.profiles(id) on delete set null,
  place_id   uuid references public.places(id) on delete set null,
  kind       text not null,
  detail     jsonb not null default '{}',
  constraint events_kind_known check (kind in (
    'paired',          -- pairing heard the box's radio
    'pair_not_heard',  -- pairing listened and heard nothing close enough
    'dock_failed',     -- a card or tag read, and the server didn't answer
    'camera_denied',   -- the scanner was refused the camera
    'bluetooth_off',   -- a paired phone with Bluetooth off, or refused
    'activities_off',  -- the lock screen ring is turned off for the app
    'box_hello'        -- the box, on a phone connecting: restarts, uptime, firmware
  )),
  constraint events_detail_small check (pg_column_size(detail) < 1024)
);

alter table public.events enable row level security;
-- No policies: nobody's client reads or writes this table directly.
revoke all on public.events from public, anon, authenticated;

create index events_place_kind_at on public.events (place_id, kind, at desc);
create index events_profile_at on public.events (profile_id, at desc);

create or replace function app.note(p_kind text, p_place uuid default null, p_detail jsonb default '{}')
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  -- A phone in a loop can't fill the table: past this, notes are dropped.
  if (select count(*) from public.events
       where profile_id = v_me and at > now() - interval '1 minute') >= 10 then
    return;
  end if;
  -- Only a box this person belongs to: a note never names someone else's.
  if p_place is not null and not exists (
      select 1 from public.place_people where place_id = p_place and profile_id = v_me) then
    p_place := null;
  end if;
  insert into public.events (profile_id, place_id, kind, detail)
  values (v_me, p_place, p_kind, coalesce(p_detail, '{}'));
end $$;

revoke all on function app.note(text, uuid, jsonb) from public;
grant execute on function app.note(text, uuid, jsonb) to authenticated;

create or replace function public.note(p_kind text, p_place uuid default null, p_detail jsonb default '{}')
returns void language sql security invoker set search_path = '' as $$
  select app.note(p_kind, p_place, p_detail)
$$;

revoke all on function public.note(text, uuid, jsonb) from public, anon;
grant execute on function public.note(text, uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------- ops
--
-- Times are the pilot's: every box is in New York for now. A box's own time
-- zone belongs on the place once there are boxes somewhere else.

create schema ops;
revoke all on schema ops from public, anon, authenticated;

-- Every box that has been used or heard from, by the name the app shows. A
-- box that has only said hello still belongs: it's the one to worry about.
create view ops.boxes as
select p.id as place_id,
       coalesce(nullif(p.name, ''), p.handle) as box,
       p.created_at as since,
       (select count(*) from public.place_people pp
         where pp.place_id = p.id and pp.left_at is null) as people
  from public.places p
 where p.merged_into is null
   and (exists (select 1 from public.gatherings g where g.place_id = p.id)
        or exists (select 1 from public.events e where e.place_id = p.id));

-- Each box, each week: evenings it kept (days with one that counted), phones
-- that counted in it, and hours someone was in it.
create view ops.box_weeks as
select b.box,
       date_trunc('week', s.local_date)::date as week,
       count(distinct s.local_date) filter (where s.qualifying) as evenings,
       count(*) filter (where s.qualifying) as phone_evenings,
       round(sum(least(s.duration_minutes, 180)) filter (where s.qualifying) / 60.0, 1) as phone_hours
  from public.sessions s
  join public.gatherings g on g.id = s.gathering_id
  join ops.boxes b on b.place_id = g.place_id
 where s.ended_at is not null
 group by b.box, week
 order by week desc, b.box;

-- When evenings start, and how long they go: across every box.
create view ops.start_hours as
select extract(hour from s.started_at at time zone 'America/New_York')::int as hour,
       count(*) as evenings,
       round(avg(least(s.duration_minutes, 180))) as average_minutes,
       count(*) filter (where s.auto_closed) as closed_at_the_cap
  from public.sessions s
 where s.qualifying
 group by hour
 order by hour;

-- Does a box keep going? Weeks since its first evening, and evenings in each.
create view ops.retention as
with first as (
  select g.place_id, min(s.local_date) as first_evening
    from public.sessions s join public.gatherings g on g.id = s.gathering_id
   where s.qualifying group by g.place_id)
select b.box,
       f.first_evening,
       ((s.local_date - f.first_evening) / 7) + 1 as week,
       count(distinct s.local_date) as evenings
  from public.sessions s
  join public.gatherings g on g.id = s.gathering_id
  join first f on f.place_id = g.place_id
  join ops.boxes b on b.place_id = g.place_id
 where s.qualifying
 group by b.box, f.first_evening, week
 order by b.box, week;

-- Is each box well? Last heard, restarts this week, its firmware, and its
-- evenings — the table to look at before anyone says it stopped working.
create view ops.box_health as
select b.box,
       b.people,
       h.last_heard,
       h.firmware,
       h.restarts_7d,
       h.last_restart_reason,
       (select max(s.ended_at) from public.sessions s join public.gatherings g on g.id = s.gathering_id
         where g.place_id = b.place_id) as last_evening,
       (select count(distinct s.local_date) from public.sessions s join public.gatherings g on g.id = s.gathering_id
         where g.place_id = b.place_id and s.qualifying and s.local_date > current_date - 7) as evenings_7d,
       (select count(*) from public.events e
         where e.place_id = b.place_id and e.kind = 'pair_not_heard' and e.at > now() - interval '7 days') as not_heard_7d
  from ops.boxes b
  left join lateral (
    select max(e.at) as last_heard,
           (array_agg(e.detail->>'fw' order by e.at desc))[1] as firmware,
           (array_agg(e.detail->>'reset' order by e.at desc))[1] as last_restart_reason,
           coalesce(max((e.detail->>'boots')::int) - min((e.detail->>'boots')::int), 0) as restarts_7d
      from public.events e
     where e.place_id = b.place_id and e.kind = 'box_hello' and e.at > now() - interval '7 days'
  ) h on true
 order by b.box;

-- What goes wrong, and how often: phones affected, not who.
create view ops.problems as
select kind,
       count(*) filter (where at > now() - interval '7 days') as last_7_days,
       count(*) filter (where at > now() - interval '30 days') as last_30_days,
       count(distinct profile_id) filter (where at > now() - interval '30 days') as phones_30_days,
       max(at) as last_seen
  from public.events
 where kind <> 'box_hello'
 group by kind
 order by last_7_days desc, kind;

revoke all on all tables in schema ops from public, anon, authenticated;
