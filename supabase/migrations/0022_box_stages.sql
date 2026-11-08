-- What a box has become, for a box in one home.
--
-- The ladder in 0003 was written for tables people visited: a regular table,
-- a reclaim house, a landmark. A box lives in one house, so "a reclaim house"
-- said nothing and "a landmark" was a public place; and a family using it most
-- nights reached the top in two months, after which nothing changed again.
--
-- The box ages the way a good object does instead. Still derived from the
-- days it has kept (any phone, fifteen minutes) — one person on their own
-- moves it exactly as a family does — and still only ever forward, because
-- the count it reads only grows. Before the first stage there is no claim,
-- only "on its way".
--
-- BoxStage.days in ReclaimKit draws the same thresholds as a track;
-- scripts/shape.sh checks the two agree.

create or replace function app.place_stage(p_evenings integer)
returns text language sql immutable set search_path = '' as $$
  select case
    when p_evenings >= 365 then 'part of the house'
    when p_evenings >= 100 then 'seasoned'
    when p_evenings >= 30  then 'settled in'
    when p_evenings >= 7   then 'broken in'
    else 'on its way'
  end
$$;

revoke all on function app.place_stage(integer) from public;
grant execute on function app.place_stage(integer) to authenticated;
