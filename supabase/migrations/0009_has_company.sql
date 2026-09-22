-- Reclaim — whether anyone else shares one of your places.
--
-- Home offers "Invite someone you'd set it down with" until you're no longer
-- on your own in any place, then stops. That needs to know if a place of yours
-- has anyone else in it — which the client can't read (place_people is
-- own-rows-only, rule 1). So this answers exactly that, as one boolean: no
-- names, no counts, nothing about who or how many.

create or replace function app.has_company()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
      from public.place_people pp
     where pp.place_id in (select app.my_place_ids())
       and pp.profile_id <> auth.uid()
       and pp.left_at is null
  )
$$;

revoke all on function app.has_company() from public;
grant execute on function app.has_company() to authenticated;

-- The wrapper PostgREST serves (see 0005).
create or replace function public.has_company()
returns boolean language sql security invoker set search_path = '' as $$
  select app.has_company()
$$;

revoke all on function public.has_company() from public, anon;
grant execute on function public.has_company() to authenticated;
