-- Reclaim — your evenings, all of them.
--
-- The end of an evening shows everything you've had so far: "27 of them, since
-- June", with tonight's among them. The client only loads its last five weeks
-- of sessions (enough for the week of dots and the grid on screen 10), and
-- `my_rhythm` answers in runs, not totals. So this answers exactly that: how
-- many distinct evenings, and the first one.
--
-- Your own rows only. Distinct `local_date`s, because a five-person dinner is
-- ONE evening — the same unit as the rhythm and the dot week. It only ever
-- goes up: nothing here can make the number smaller except deleting an
-- evening yourself.

create or replace function app.my_evenings()
returns table (evenings integer, first_evening date)
language sql stable security definer set search_path = '' as $$
  select count(distinct s.local_date)::integer, min(s.local_date)
    from public.sessions s
   where s.profile_id = auth.uid()
     and s.qualifying
$$;

revoke all on function app.my_evenings() from public;
grant execute on function app.my_evenings() to authenticated;

-- The wrapper PostgREST serves (see 0005).
create or replace function public.my_evenings()
returns table (evenings integer, first_evening date)
language sql security invoker set search_path = '' as $$
  select * from app.my_evenings()
$$;

revoke all on function public.my_evenings() from public, anon;
grant execute on function public.my_evenings() to authenticated;
