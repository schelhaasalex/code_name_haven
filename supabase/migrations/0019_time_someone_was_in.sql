-- Reclaim — a box's hours are the time someone was in it.
--
-- 0018 ended each evening where its last credited stretch ended. One test
-- evening showed why that isn't enough: a phone left in at 10pm, capped at
-- three hours, and a second phone that joined the still-open evening for a
-- minute at 1:48pm the next day. First phone in to last stretch's end was
-- fifteen hours, nearly all of them with nobody there.
--
-- An evening's hours are now the union of its credited stretches — from
-- when each started, for as long as it was credited — with the gaps between
-- them left out. Two people together for an hour is an hour; one after the
-- other is both.

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
  with stretches as (
    select s.gathering_id,
           s.started_at                                            as from_at,
           s.started_at + make_interval(mins => s.duration_minutes) as to_at
      from public.sessions s
      join public.gatherings g on g.id = s.gathering_id
     where g.place_id = p_place
       and g.ended_at is not null
       and s.ended_at is not null
       and exists (select 1 from public.sessions q
                    where q.gathering_id = g.id and q.qualifying)
  ),
  -- A stretch that starts after everything before it has ended begins a new
  -- island; one that starts inside it joins it.
  marked as (
    select *, case when from_at > max(to_at) over (
                     partition by gathering_id order by from_at, to_at
                     rows between unbounded preceding and 1 preceding)
                   then 1 else 0 end as starts
      from stretches
  ),
  islands as (
    select gathering_id, from_at, to_at,
           sum(starts) over (partition by gathering_id order by from_at, to_at) as island
      from marked
  )
  select
    v_evenings,
    coalesce((
      select sum(floor(extract(epoch from (i.until - i.since)) / 60))::int
        from (select min(from_at) as since, max(to_at) as until
                from islands group by gathering_id, island) i), 0),
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
