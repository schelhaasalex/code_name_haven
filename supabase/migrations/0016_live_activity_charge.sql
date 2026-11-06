-- Reclaim — the evening charges, on the lock screen and the wrist.
--
-- The ring fills in four steps: fifteen minutes, half an hour, an hour, an
-- hour and a half, and then it holds. A light joins it for each person who
-- has put their phone down. None of that can happen on the phone by itself:
-- a Live Activity only changes when the app updates it or a push arrives, and
-- the app is asleep in a drawer. So the server sends the steps.
--
-- Each running Live Activity hands the phone a token of its own — not the
-- push-to-start token in 0015, which addresses the device. The phone files it
-- here with the activity's state as it encoded it. Once a minute the
-- charge-live-activities Edge Function asks app.claim_charges which
-- activities have something new to show, and pushes exactly that.
--
-- The stage is counted from the activity's own startedAt — the "since 7:27"
-- the person reads — and the light from everyone who has joined the
-- gathering, never down (rule 3).

create table public.live_activities (
  token         text        primary key,
  profile_id    uuid        not null references public.profiles(id) on delete cascade,
  gathering_id  uuid        not null references public.gatherings(id) on delete cascade,
  environment   text        not null,
  -- The ContentState exactly as the phone's JSONEncoder wrote it. The server
  -- only ever replaces `stage` and `memberCount`; the date stays the phone's.
  state         jsonb       not null,
  stage_sent    integer     not null default 0,
  members_sent  integer     not null default 1,
  updated_at    timestamptz not null default now(),
  constraint live_activities_environment check (environment in ('sandbox', 'production')),
  constraint live_activities_token_shape check (token ~ '^[0-9a-f]+$' and length(token) between 32 and 400),
  constraint live_activities_started check (coalesce(jsonb_typeof(state -> 'startedAt'), '') = 'number')
);

create index live_activities_gathering on public.live_activities (gathering_id);

-- A token puts something on a lock screen. Nobody reads these from a phone.
alter table public.live_activities enable row level security;
revoke all on public.live_activities from anon, authenticated;

-- ------------------------------------------------------------- the steps

-- How many of the four segments are full after this many minutes. The same
-- four numbers are EveningCharge.minutes in ReclaimKit; scripts/shape.sh
-- checks they agree. The first is the fifteen minutes an evening needs to
-- count, so "Tonight counts." is true when it appears.
create or replace function app.charge_stage(p_minutes double precision)
returns integer language sql immutable set search_path = '' as $$
  select count(*)::integer from unnest(array[15, 30, 60, 90]) as m where p_minutes >= m
$$;

-- ActivityKit's dates are seconds since 2001, which is what the phone wrote.
create or replace function app.charge_minutes(p_state jsonb, p_at timestamptz default now())
returns double precision language sql stable set search_path = '' as $$
  select (extract(epoch from p_at) - 978307200 - (p_state ->> 'startedAt')::double precision) / 60
$$;

-- ------------------------------------------------------------- filing

-- Only for an evening you're in. The token is yours from then on, whoever
-- had it before.
create or replace function app.save_live_activity(
  p_token text, p_gathering uuid, p_environment text, p_state text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me    uuid := auth.uid();
  v_state jsonb := p_state::jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.sessions s
                  where s.gathering_id = p_gathering and s.profile_id = v_me) then
    raise exception 'not a member of this gathering';
  end if;

  insert into public.live_activities
    (token, profile_id, gathering_id, environment, state, stage_sent, members_sent)
  values (lower(p_token), v_me, p_gathering, p_environment, v_state,
          coalesce((v_state ->> 'stage')::integer, 0),
          coalesce((v_state ->> 'memberCount')::integer, 1))
  on conflict (token) do update
     set profile_id   = excluded.profile_id,
         gathering_id = excluded.gathering_id,
         environment  = excluded.environment,
         state        = excluded.state,
         stage_sent   = excluded.stage_sent,
         members_sent = excluded.members_sent,
         updated_at   = now();
end $$;

revoke all on function app.save_live_activity(text, uuid, text, text) from public;
grant execute on function app.save_live_activity(text, uuid, text, text) to authenticated;

create or replace function public.save_live_activity(
  p_token text, p_gathering uuid, p_environment text, p_state text)
returns void language sql security invoker set search_path = '' as $$
  select app.save_live_activity(p_token, p_gathering, p_environment, p_state)
$$;

revoke all on function public.save_live_activity(text, uuid, text, text) from public, anon;
grant execute on function public.save_live_activity(text, uuid, text, text) to authenticated;

-- ------------------------------------------------------------- claiming

-- What each activity should show now that it isn't showing yet, marked as
-- sent in the same breath — two runs at once never push the same step twice.
-- An evening the person is no longer in is an 'end', and forgotten: ended in
-- the app, by the End button, or closed by auto_close_stale overnight.
--
-- At most once, deliberately: a push Apple refuses isn't retried, and the
-- next step carries everything the missed one would have.
create or replace function app.claim_charges(p_at timestamptz default now())
returns table (token text, environment text, event text, state jsonb)
language plpgsql security definer set search_path = '' as $$
declare
  r         record;
  v_live    boolean;
  v_members integer;
  v_stage   integer;
begin
  for r in select a.* from public.live_activities a for update skip locked loop
    select bool_or(s.ended_at is null) into v_live
      from public.sessions s
     where s.gathering_id = r.gathering_id and s.profile_id = r.profile_id;

    select greatest(count(distinct s.profile_id), 1)::integer into v_members
      from public.sessions s where s.gathering_id = r.gathering_id;

    v_stage := least(4, greatest(0, app.charge_stage(app.charge_minutes(r.state, p_at))));

    token := r.token;
    environment := r.environment;
    state := r.state || jsonb_build_object('stage', v_stage, 'memberCount', v_members);

    if not coalesce(v_live, false) then
      delete from public.live_activities a where a.token = r.token;
      event := 'end';
      return next;
    elsif v_stage <> r.stage_sent or v_members <> r.members_sent then
      update public.live_activities a
         set stage_sent = v_stage, members_sent = v_members, updated_at = now()
       where a.token = r.token;
      event := 'update';
      return next;
    end if;
  end loop;
end $$;

revoke all on function app.claim_charges(timestamptz) from public, anon, authenticated;

-- Apple refused the token: the activity is gone.
create or replace function app.forget_live_activity(p_token text)
returns void language sql security definer set search_path = '' as $$
  delete from public.live_activities where token = lower(p_token)
$$;

revoke all on function app.forget_live_activity(text) from public, anon, authenticated;

-- For the Edge Function, which calls as the service role. No phone may: the
-- pushes are what happens TO an evening, not something anyone asks for.
--
-- The function is called by the minute's job, not by a signed-in person, so
-- it can't check a JWT. The job sends a key from Vault ('charge_key', made
-- below), the function passes it on, and it's checked here, where Vault is —
-- the key itself never leaves the database. plpgsql, so it creates on a bare
-- Postgres that has no Vault; the tests call app.claim_charges directly.
create or replace function public.claim_charges(p_key text)
returns table (token text, environment text, event text, state jsonb)
language plpgsql security definer set search_path = '' as $$
begin
  if p_key is null or p_key is distinct from
     (select decrypted_secret from vault.decrypted_secrets where name = 'charge_key') then
    raise exception 'not the minute''s job';
  end if;
  return query select * from app.claim_charges();
end $$;

create or replace function public.forget_live_activity(p_token text)
returns void language sql security invoker set search_path = '' as $$
  select app.forget_live_activity(p_token)
$$;

revoke all on function public.claim_charges(text) from public, anon, authenticated;
revoke all on function public.forget_live_activity(text) from public, anon, authenticated;
grant usage on schema app to service_role;
grant execute on function app.claim_charges(timestamptz), public.claim_charges(text) to service_role;
grant execute on function app.forget_live_activity(text), public.forget_live_activity(text) to service_role;

-- ------------------------------------------------------------- the minute

-- Once a minute, where pg_cron, pg_net and Vault exist — the hosted project.
-- The function's address is read from Vault too ('project_url', e.g.
-- https://<ref>.supabase.co), so it isn't written into the repository; it has
-- to be added once, by hand, before the job reaches anything.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron')
     and exists (select 1 from pg_available_extensions where name = 'pg_net')
     and exists (select 1 from pg_namespace where nspname = 'vault') then
    create extension if not exists pg_cron with schema pg_catalog;
    create extension if not exists pg_net;
    if not exists (select 1 from vault.secrets where name = 'charge_key') then
      perform vault.create_secret(
        replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''), 'charge_key');
    end if;
    perform cron.unschedule(jobid) from cron.job where jobname = 'charge-live-activities';
    perform cron.schedule('charge-live-activities', '* * * * *', $job$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
               || '/functions/v1/charge-live-activities',
        headers := jsonb_build_object(
          'content-type', 'application/json',
          'x-charge-key', (select decrypted_secret from vault.decrypted_secrets where name = 'charge_key')),
        body := '{}'::jsonb)
    $job$);
  else
    raise notice 'pg_cron, pg_net or Vault is not available here; the charge is not scheduled';
  end if;
end $$;
