-- Reclaim — joining the table you are sitting at, with nothing to scan.
--
-- The card on the table works, but it has to exist: someone printed it, it
-- stayed where it was put, and a guest thought to touch their phone to it.
-- Proximity is the same moment with none of that — one phone already down,
-- the others noticing from across the table. It is the puck's software
-- rehearsal (CLAUDE.md, scope).
--
-- WHAT GOES OVER THE AIR IS A KEY, NOT AN ADDRESS. A place id would do the
-- job — app.start_or_join takes one and makes you one of that place's people
-- — and that is exactly why it must not be broadcast: it never expires, so a
-- phone in range for one evening would hold a way into that house forever.
-- A key here is worthless the moment the evening ends. Joining by radio can
-- only ever put you at a table that is set RIGHT NOW, which is the whole of
-- what proximity is allowed to mean.
--
-- The key is minted here, not on the phone, and only its hash is stored —
-- like places.join_secret_hash and invites.token_hash. Reading every row in
-- this table still lets nobody in anywhere.
--
-- WHAT THE OTHER PHONE LEARNS BEFORE IT JOINS: that an evening near it is
-- open, how many phones are down, and when it started. No name, no place, no
-- person — screen 4 says "someone nearby", because that is all the app knows
-- until you tap. Compare app.accept_invite, which may name the place and who
-- asked: by then you are one of its people.

-- Where the evening came from, for the one screen that says so (screen 8) and
-- for knowing later which entrances people actually use.
alter table public.sessions drop constraint sessions_source_known;
alter table public.sessions add constraint sessions_source_known check (
  source in ('app','tag','control','siri','shortcut','retroactive','nearby'));

create table public.nearby_keys (
  token_hash   text primary key,
  gathering_id uuid not null references public.gatherings(id) on delete cascade,
  created_at   timestamptz not null default now(),
  -- A backstop, not the rule. What really ends a key is the evening ending,
  -- which every lookup below checks; this only stops a key outliving a
  -- gathering that was never closed properly.
  expires_at   timestamptz not null default now() + interval '12 hours'
);

create index nearby_keys_gathering on public.nearby_keys (gathering_id);

-- Functions only. Supabase hands every new table GRANT ALL to anon and
-- authenticated, and 0002's default privileges should have stopped that —
-- revoked again anyway, because this table is the way into an open evening.
alter table public.nearby_keys enable row level security;
revoke all on public.nearby_keys from anon, authenticated;

-- ------------------------------------------------------------ being findable

-- What the phone that is already down broadcasts. Called when an evening
-- starts and whenever the radio needs a key again.
--
-- Returns NULL rather than raising when there is nothing to advertise —
-- nothing running, or an evening at no place. A placeless evening is not
-- findable on purpose: joining one over the air would make you one of the
-- people of a place that doesn't exist yet. Name it (screens 6, 7, 21) and
-- the table appears on the radio.
--
-- Several keys per gathering are fine. The phone may be relaunched mid-
-- evening, and minting a new key must not silently break the one another
-- phone read a minute ago.
create or replace function app.open_nearby()
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_me        uuid := auth.uid();
  v_gathering uuid;
  v_token     text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select g.id into v_gathering
    from public.sessions s
    join public.gatherings g on g.id = s.gathering_id
   where s.profile_id = v_me and s.ended_at is null
     and g.ended_at is null and g.place_id is not null;

  if v_gathering is null then return null; end if;

  -- 18 random bytes, url-safe: it travels as text over Bluetooth.
  v_token := translate(encode(extensions.gen_random_bytes(18), 'base64'), '+/=', '-_');

  insert into public.nearby_keys (token_hash, gathering_id)
  values (encode(extensions.digest(v_token, 'sha256'), 'hex'), v_gathering);

  return v_token;
end $$;

-- ---------------------------------------------------------------- the offer

-- What screen 4 needs to ask the question, and not one field more. No rows
-- when the key is spent, the evening is over, or you are already in it —
-- there is nothing to offer someone who is already at the table.
--
-- The count is an aggregate of people who HAVE set theirs down, like every
-- other count in the product: it can only go up, and it names nobody.
create or replace function app.nearby_offer(p_token text)
returns table (gathering uuid, people integer, since timestamptz)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_me     uuid := auth.uid();
  v_id     uuid;
  v_since  timestamptz;
  v_people integer;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select g.id, g.started_at into v_id, v_since
    from public.nearby_keys k
    join public.gatherings g on g.id = k.gathering_id
   where k.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
     and k.expires_at > now()
     and g.ended_at is null;

  if v_id is null then return; end if;
  if exists (select 1 from public.sessions s
              where s.gathering_id = v_id and s.profile_id = v_me) then return; end if;

  select count(*) into v_people from public.sessions s where s.gathering_id = v_id;

  return query select v_id, v_people, v_since;
end $$;

-- ---------------------------------------------------------------- the answer

-- The one button on screen 4, when the offer came over the air. The key turns
-- into a place HERE and never leaves this function, so a phone that only
-- listened is left holding nothing it can use tomorrow.
--
-- Both ways in are the ones that already exist: an evening of your own moves
-- to the table (0007), and otherwise you join it the way every other entrance
-- does (0003). Returns the gathering you are now in.
create or replace function app.join_nearby(p_token text, p_tz text default 'UTC')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me        uuid := auth.uid();
  v_gathering uuid;
  v_place     uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select g.id, g.place_id into v_gathering, v_place
    from public.nearby_keys k
    join public.gatherings g on g.id = k.gathering_id
   where k.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
     and k.expires_at > now()
     and g.ended_at is null;

  -- The evening ended between the offer and the tap. Said plainly; the phone
  -- turns it into "that one's over" rather than an error.
  if v_gathering is null then raise exception 'that evening is over'; end if;
  if v_place is null then raise exception 'that evening is at no place'; end if;

  if exists (select 1 from public.sessions s
              where s.profile_id = v_me and s.ended_at is null) then
    return app.move_evening(v_place);
  end if;

  perform app.start_or_join(v_place, 'nearby', p_tz);

  -- Not v_gathering: if that evening ended in the half-second since, you are
  -- in the one start_or_join just opened at the same table.
  select s.gathering_id into v_gathering
    from public.sessions s
   where s.profile_id = v_me and s.ended_at is null;

  return v_gathering;
end $$;

revoke all on function app.open_nearby(), app.nearby_offer(text), app.join_nearby(text, text)
  from public;
grant execute on function app.open_nearby(), app.nearby_offer(text), app.join_nearby(text, text)
  to authenticated;

-- The wrappers PostgREST serves (see 0005).

create or replace function public.open_nearby()
returns text language sql security invoker set search_path = '' as $$
  select app.open_nearby()
$$;

create or replace function public.nearby_offer(p_token text)
returns table (gathering uuid, people integer, since timestamptz)
language sql security invoker set search_path = '' as $$
  select * from app.nearby_offer(p_token)
$$;

create or replace function public.join_nearby(p_token text, p_tz text default 'UTC')
returns uuid language sql security invoker set search_path = '' as $$
  select app.join_nearby(p_token, p_tz)
$$;

revoke all on function public.open_nearby(), public.nearby_offer(text), public.join_nearby(text, text)
  from public, anon;
grant execute on function public.open_nearby(), public.nearby_offer(text), public.join_nearby(text, text)
  to authenticated;
