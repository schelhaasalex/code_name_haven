-- Reclaim — every evening is credited at most the cap, however it ends.
--
-- The cap (app.auto_close_minutes, three hours) was only ever applied by
-- auto_close_stale, the scheduled job that closes an evening nobody ended. An
-- evening ended by hand was credited its whole span — and before the job was
-- scheduled (0014), nothing closed anything, so a phone left in the box from
-- 10pm and taken out at 4pm the next day was credited 17¾ hours. The job
-- runs every five minutes now, so that became rare; rare is not never.
--
-- And a box's total (place_summary.wall_clock_minutes) added up each
-- evening's span — first phone in to last phone out — with no cap at all. It
-- now ends each evening where its credited stretches end: a stretch counts
-- from when it started for as long as it was credited.
--
-- Last, the evenings already over the cap are brought down to it.

create or replace function app.end_session(p_session uuid default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_me       uuid := auth.uid();
  v_id       uuid;
  v_gather   uuid;
  v_minutes  integer;
  v_total    integer;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select id into v_id
    from public.sessions
   where profile_id = v_me and ended_at is null
     and (p_session is null or id = p_session)
   limit 1;

  if v_id is null then return null; end if;

  -- Ended when it ended; credited at most the cap, as auto_close_stale does.
  update public.sessions
     set ended_at         = now(),
         duration_minutes = least(floor(extract(epoch from (now() - started_at)) / 60)::int,
                                  app.auto_close_minutes())
   where id = v_id
  returning gathering_id, duration_minutes into v_gather, v_minutes;

  -- Whether the evening counted is a question about the evening, not the
  -- stretch: every stretch of yours in it, together.
  select coalesce(sum(duration_minutes), 0) into v_total
    from public.sessions
   where gathering_id = v_gather and profile_id = v_me and ended_at is not null;

  update public.sessions
     set qualifying = v_total >= app.qualifying_minutes()
   where gathering_id = v_gather and profile_id = v_me and ended_at is not null;

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
    -- Each evening from its first phone in to the end of its last credited
    -- stretch, never past when it actually ended.
    coalesce((
      select sum(greatest(0, floor(extract(epoch from (
               least(g.ended_at, e.credited_until) - g.started_at)) / 60)))::int
        from public.gatherings g
        cross join lateral (
          select max(s.started_at + make_interval(mins => s.duration_minutes)) as credited_until
            from public.sessions s
           where s.gathering_id = g.id and s.ended_at is not null) e
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

-- The evenings already credited past the cap. Their end stays when it was;
-- only what they're credited changes. Every one of them still qualifies: the
-- cap is longer than the qualifying minimum.
update public.sessions
   set duration_minutes = app.auto_close_minutes()
 where duration_minutes > app.auto_close_minutes();
