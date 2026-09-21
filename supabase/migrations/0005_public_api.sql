-- The client-facing API surface, in `public`.
--
-- Why this exists: PostgREST only serves schemas listed in the project's
-- "Exposed schemas" setting, which is `public, graphql_public` by default. Every
-- function in 0003 lives in `app`, so a client calling them would get a 404 —
-- and the failure reads like a missing function rather than a config gap.
--
-- Two ways out: add `app` to the exposed schemas in the dashboard, or put thin
-- wrappers in `public`. Wrappers win, because a manual dashboard step is a thing
-- someone forgets when they stand up a second project, and because it makes the
-- client-facing surface explicit and reviewable — `app` stays internal, and what
-- a phone is allowed to call is exactly this file.
--
-- Each wrapper is SECURITY INVOKER: it runs as the caller, then calls the
-- SECURITY DEFINER function in `app`, which does the privileged work. auth.uid()
-- resolves the same either way, since it reads a session setting.
--
-- app.auto_close_stale is deliberately NOT wrapped. It runs from a scheduler.

create or replace function public.resolve_place(p_secret text)
returns uuid language sql security invoker set search_path = '' as $$
  select app.resolve_place(p_secret)
$$;

create or replace function public.create_place(
  p_handle text, p_secret text, p_name text default null)
returns uuid language sql security invoker set search_path = '' as $$
  select app.create_place(p_handle, p_secret, p_name)
$$;

create or replace function public.start_or_join(
  p_place uuid default null, p_source text default 'app', p_tz text default 'UTC')
returns uuid language sql security invoker set search_path = '' as $$
  select app.start_or_join(p_place, p_source, p_tz)
$$;

create or replace function public.end_session(p_session uuid default null)
returns integer language sql security invoker set search_path = '' as $$
  select app.end_session(p_session)
$$;

create or replace function public.record_retroactive(
  p_started timestamptz, p_ended timestamptz, p_tz text default 'UTC')
returns uuid language sql security invoker set search_path = '' as $$
  select app.record_retroactive(p_started, p_ended, p_tz)
$$;

create or replace function public.gathering_members(p_gathering uuid)
returns table (profile_id uuid, display_name text, still_live boolean)
language sql security invoker set search_path = '' as $$
  select * from app.gathering_members(p_gathering)
$$;

create or replace function public.place_summary(p_place uuid)
returns table (
  evenings integer, wall_clock_minutes integer, person_minutes integer,
  stage text, since date, live_now boolean)
language sql security invoker set search_path = '' as $$
  select * from app.place_summary(p_place)
$$;

create or replace function public.my_rhythm()
returns table (
  state text, current_run_days integer, longest_run_days integer,
  last_qualifying_date date, rest_day_available boolean)
language sql security invoker set search_path = '' as $$
  select * from app.my_rhythm()
$$;

create or replace function public.name_somewhere(
  p_handle text, p_secret text, p_name text)
returns uuid language sql security invoker set search_path = '' as $$
  select app.name_somewhere(p_handle, p_secret, p_name)
$$;

create or replace function public.merge_places(p_from uuid, p_into uuid)
returns void language sql security invoker set search_path = '' as $$
  select app.merge_places(p_from, p_into)
$$;

-- 0002 revoked the default function grants in public and stopped them
-- re-applying, so these arrive with no grants at all. Hand them out explicitly,
-- and to `authenticated` only — anon has no surface in this app.

revoke all on function
  public.resolve_place(text), public.create_place(text, text, text),
  public.start_or_join(uuid, text, text), public.end_session(uuid),
  public.record_retroactive(timestamptz, timestamptz, text),
  public.gathering_members(uuid), public.place_summary(uuid), public.my_rhythm(),
  public.name_somewhere(text, text, text), public.merge_places(uuid, uuid)
from public, anon;

grant execute on function
  public.resolve_place(text), public.create_place(text, text, text),
  public.start_or_join(uuid, text, text), public.end_session(uuid),
  public.record_retroactive(timestamptz, timestamptz, text),
  public.gathering_members(uuid), public.place_summary(uuid), public.my_rhythm(),
  public.name_somewhere(text, text, text), public.merge_places(uuid, uuid)
to authenticated;
