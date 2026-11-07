-- Reclaim — deleting an account deletes the account, and the hours stay.
--
-- The app deleted its own profile row and signed out. The login itself — the
-- auth.users row — stayed behind, and only the server can remove it. And the
-- profile took every evening with it (sessions cascaded), so a box's total
-- went down for everyone else in the house: the one place a count fell.
--
-- Now one call does it all, on the server: any evening still running ends,
-- the login goes, and the profile goes with it. The evenings stay, with
-- nothing that says whose they were — profile_id becomes null — so the hours
-- the house spent at its boxes stay in their totals. Nobody can read those
-- rows: sessions are own-rows only, and a null owner is nobody's.

alter table public.sessions alter column profile_id drop not null;
alter table public.sessions drop constraint sessions_profile_id_fkey;
alter table public.sessions add constraint sessions_profile_id_fkey
  foreign key (profile_id) references public.profiles(id) on delete set null;

create or replace function app.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  -- Credited and capped like any other ending, before it loses its owner.
  perform app.end_session();
  -- The profile, its boxes' memberships and its tokens cascade from here;
  -- its evenings are kept, unowned.
  delete from auth.users where id = v_me;
end $$;

revoke all on function app.delete_my_account() from public;
grant execute on function app.delete_my_account() to authenticated;

create or replace function public.delete_my_account()
returns void language sql security invoker set search_path = '' as $$
  select app.delete_my_account()
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
