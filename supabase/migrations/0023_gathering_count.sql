-- 0023: who's in an evening, as a number.
--
-- Safe to apply at once: it only adds. The app from this release calls
-- `gathering_count`; builds before it call `gathering_members`, which 0024
-- drops once they're gone.

-- ------------------------------------------------- who's in it, as a number

-- `gathering_members` handed every phone in an evening the account id and
-- name of everyone else in it. The app only ever counted them (rule 1: what
-- crosses a person boundary is an aggregate). Everyone who joined, once,
-- however many stretches — the count goes up, never down (rule 3).
create or replace function app.gathering_count(p_gathering uuid)
returns integer
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.sessions s
                  where s.gathering_id = p_gathering and s.profile_id = auth.uid())
  then
    raise exception 'not a member of this gathering';
  end if;

  return (select count(distinct s.profile_id)::integer
            from public.sessions s
           where s.gathering_id = p_gathering);
end $$;

revoke all on function app.gathering_count(uuid) from public;
grant execute on function app.gathering_count(uuid) to authenticated;

create or replace function public.gathering_count(p_gathering uuid)
returns integer
language sql security invoker set search_path = '' as $$
  select app.gathering_count(p_gathering)
$$;

revoke all on function public.gathering_count(uuid) from public, anon;
grant execute on function public.gathering_count(uuid) to authenticated;
