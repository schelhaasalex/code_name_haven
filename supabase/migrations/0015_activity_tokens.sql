-- Reclaim — a Live Activity the server can put on the lock screen.
--
-- iOS only lets an app start a Live Activity while it is on screen. The box
-- starts an evening with the phone locked in a drawer, the app woken for a
-- few seconds over Bluetooth, and the request is refused: the evening counts,
-- and nothing shows until the person next opens the app. iOS 17.2 added
-- push-to-start — a push from a server, to a token the phone hands out, that
-- starts the activity with the app asleep. The phone keeps its token here;
-- the start-live-activity Edge Function reads it, with the service role, and
-- asks Apple.
--
-- A token addresses one device, so it is the key; a person with two phones
-- has two. 'sandbox' for builds run from Xcode, 'production' for TestFlight
-- and the App Store — Apple keeps them apart, and a token sent to the wrong
-- one is refused.

create table public.activity_tokens (
  token        text        primary key,
  profile_id   uuid        not null references public.profiles(id) on delete cascade,
  environment  text        not null,
  updated_at   timestamptz not null default now(),
  constraint activity_tokens_environment check (environment in ('sandbox', 'production')),
  constraint activity_tokens_token_shape check (token ~ '^[0-9a-f]+$' and length(token) between 32 and 400)
);

create index activity_tokens_profile on public.activity_tokens (profile_id);

-- Nobody reads or writes this from a phone directly: a token is a way to put
-- something on someone's lock screen. 0002's default privileges should
-- already hold; revoked again regardless.
alter table public.activity_tokens enable row level security;
revoke all on public.activity_tokens from anon, authenticated;

-- Yours, and only ever yours: a token someone else had registered moves to
-- you, because the device is the one in your hand now.
create or replace function app.save_activity_token(p_token text, p_environment text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  insert into public.activity_tokens (token, profile_id, environment)
  values (lower(p_token), v_me, p_environment)
  on conflict (token) do update
     set profile_id  = excluded.profile_id,
         environment = excluded.environment,
         updated_at  = now();
end $$;

revoke all on function app.save_activity_token(text, text) from public;
grant execute on function app.save_activity_token(text, text) to authenticated;

-- The wrapper PostgREST serves (see 0005).
create or replace function public.save_activity_token(p_token text, p_environment text)
returns void language sql security invoker set search_path = '' as $$
  select app.save_activity_token(p_token, p_environment)
$$;

revoke all on function public.save_activity_token(text, text) from public, anon;
grant execute on function public.save_activity_token(text, text) to authenticated;
