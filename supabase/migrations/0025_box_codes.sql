-- 0025: a box's code, shown by a phone already in it.
--
-- With the slots' tags gone, a lost card left no way for a new phone into a
-- box: the app sends the card's secret to dock_place once and keeps nothing,
-- and the server keeps only its hash. Now anyone in a box can ask for a fresh
-- code, show it on their screen, and a second phone scans it exactly as it
-- would the card. It is the same link, so nothing on the scanning side changes.
--
-- A code lasts an hour. The card stays the box's standing key; a code is for
-- the moment someone is standing beside the box with a new phone.
--
-- THE TRAP. dock_place makes a new box from any secret it doesn't know — that
-- is how a factory card works on its first scan. A code that had run out would
-- be a secret it doesn't know, and would quietly make whoever scanned it a
-- new, empty box. So a code is never forgotten: once made, its hash is kept,
-- and a secret that matches one, live or not, never makes a box.
--
-- Rule 1 holds: box_code hands you a key to a box you are in, and nothing
-- about anyone else.

create table app.place_codes (
  code_hash  text primary key,
  place_id   uuid not null references public.places(id) on delete cascade,
  made_by    uuid references public.profiles(id) on delete set null,
  made_at    timestamptz not null default now(),
  expires_at timestamptz not null
);
create index place_codes_place_id_idx on app.place_codes (place_id);

-- `app` isn't served, but nothing should depend on that alone.
revoke all on app.place_codes from public, anon, authenticated;

-- ------------------------------------------------------- resolving a secret
-- The card first, then a live code. Merge chains followed as before.

create or replace function app.resolve_place(p_secret text)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare
  v_hash text := encode(extensions.digest(p_secret, 'sha256'), 'hex');
  v_id   uuid;
  v_next uuid;
  v_hops integer := 0;
begin
  select id into v_id from public.places where join_secret_hash = v_hash;

  if v_id is null then
    select place_id into v_id from app.place_codes
     where code_hash = v_hash and expires_at > now();
  end if;

  if v_id is null then
    return null;
  end if;

  loop
    select merged_into into v_next from public.places where id = v_id;
    exit when v_next is null;
    v_id := v_next;
    v_hops := v_hops + 1;
    if v_hops > 16 then
      raise exception 'merge chain too deep for place %', v_id;
    end if;
  end loop;

  return v_id;
end $$;

-- ------------------------------------------------------- reading a box
-- As 0017, with the trap closed: a code that has run out raises `RC410`
-- rather than falling through to making a box. The app tells the person to
-- ask for a fresh one.

create or replace function app.dock_place(p_secret text, p_handle text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  v_id := app.resolve_place(p_secret);

  if v_id is null then
    if exists (select 1 from app.place_codes
                where code_hash = encode(extensions.digest(p_secret, 'sha256'), 'hex')) then
      raise exception 'this code has run out' using errcode = 'RC410';
    end if;

    -- No conflict target: losing the race on the secret and drawing a handle
    -- someone else has are both "not this time", and the lookup after says which.
    insert into public.places (handle, join_secret_hash, created_by)
    values (p_handle, encode(extensions.digest(p_secret, 'sha256'), 'hex'), v_me)
    on conflict do nothing
    returning id into v_id;

    if v_id is null then
      v_id := app.resolve_place(p_secret);
    end if;
  end if;

  -- Still nothing: the handle was taken. The phone draws another.
  if v_id is null then
    return null;
  end if;

  insert into public.place_people (place_id, profile_id) values (v_id, v_me)
  on conflict (place_id, profile_id) do update set left_at = null;
  return v_id;
end $$;

-- ------------------------------------------------------- making a code
-- Only for someone in the box now. The secret is made here, the same shape as
-- a card's (32 random bytes, URL-safe), and only its hash is kept.

create or replace function app.box_code(p_place uuid)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me     uuid := auth.uid();
  v_secret text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  if not exists (select 1 from public.place_people
                  where place_id = p_place and profile_id = v_me and left_at is null) then
    raise exception 'not one of this box''s people' using errcode = '42501';
  end if;

  v_secret := translate(encode(extensions.gen_random_bytes(32), 'base64'), '+/=', '-_');

  insert into app.place_codes (code_hash, place_id, made_by, expires_at)
  values (encode(extensions.digest(v_secret, 'sha256'), 'hex'), p_place, v_me,
          now() + interval '1 hour');

  return v_secret;
end $$;

revoke all on function app.box_code(uuid) from public;
grant execute on function app.box_code(uuid) to authenticated;

-- The wrapper PostgREST serves (see 0005).
create or replace function public.box_code(p_place uuid)
returns text language sql volatile security invoker set search_path = '' as $$
  select app.box_code(p_place)
$$;

revoke all on function public.box_code(uuid) from public, anon;
grant execute on function public.box_code(uuid) to authenticated;
