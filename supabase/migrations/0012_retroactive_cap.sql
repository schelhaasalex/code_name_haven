-- Reclaim — an evening you didn't start is still only ever an evening.
--
-- `auto_close_stale` has credited at the CAP since 0003, and the reason is
-- written there: nine hours of phone-on-the-side becoming nine hours of
-- "reclaimed" makes the number mean nothing, and the cheapest strategy in the
-- product becomes forgetting to end a session. `record_retroactive` was
-- credited the same way and capped by nothing at all — it wrote whatever span
-- it was handed.
--
-- It went unnoticed because `PreviewRepository` caps at three hours, so every
-- run of screen 18 in a simulator showed a sensible number. A fixture that is
-- STRICTER than production hides exactly the bug it should have found.
--
-- What it took to notice: the first TestFlight launch offered nine hours and
-- four minutes of somebody's sleep as an evening, and one tap would have
-- written it down. The offer itself is now the person's own business
-- (`StationaryRuns`), and this is the floor under it — the client cannot ask
-- for more than an evening, whatever it believes.
--
-- Both the timestamps and the minutes are clamped, together, the way
-- auto-close does it: an evening that says it ran until 6am and counted three
-- hours is two answers to one question.

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
  v_ended   timestamptz;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_ended <= p_started then raise exception 'retroactive session ends before it starts'; end if;

  v_ended := least(p_ended, p_started + make_interval(mins => app.auto_close_minutes()));
  v_minutes := floor(extract(epoch from (v_ended - p_started)) / 60)::int;

  insert into public.gatherings (place_id, started_by, started_at, ended_at)
  values (null, v_me, p_started, v_ended)
  returning id into v_gather;

  insert into public.sessions (
    profile_id, gathering_id, started_at, ended_at, duration_minutes,
    local_date, qualifying, retroactive, source)
  values (
    v_me, v_gather, p_started, v_ended, v_minutes,
    (p_started at time zone p_tz)::date,
    v_minutes >= app.qualifying_minutes(), true, 'retroactive')
  returning id into v_id;

  return v_id;
end $$;
