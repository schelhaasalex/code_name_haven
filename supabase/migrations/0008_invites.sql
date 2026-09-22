-- Reclaim — inviting someone to a place, from a distance.
--
-- People are connected only through places: you hear that someone set their
-- phone down only if you both belong to where they did it (0006). So an
-- invitation is an invitation to a PLACE — the text-message version of the
-- card on the table — and accepting one makes you one of its people. It
-- STARTS NOTHING: a card says "I'm at this table"; a link opened from
-- Messages on a Tuesday says no such thing.
--
-- Why not reuse the card's secret: a printed card lives in a house, and using
-- it means being there. A message can be forwarded to anyone, and anyone who
-- joins a place can see its people's names. So invitations get their own
-- tokens, which expire after a week. One link can be used by several people
-- in that week — a family group chat is the common case.
--
-- The token is minted here, not on the phone, so no client can choose one,
-- and only its hash is stored — like places.join_secret_hash, reading every
-- row still lets nobody in.

create table public.invites (
  token_hash  text primary key,
  place_id    uuid not null references public.places(id)   on delete cascade,
  created_by  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '7 days',
  uses        integer not null default 0 check (uses >= 0)
);

create index invites_place on public.invites (place_id);

-- Functions only. Supabase hands every new table GRANT ALL to anon and
-- authenticated, and 0002's default privileges should have stopped that —
-- revoked again anyway, because this table holds the way into a place.
alter table public.invites enable row level security;
revoke all on public.invites from anon, authenticated;

-- A week, as a function like the other product rules, so the copy and the
-- database can't disagree about it.
create or replace function app.invite_days() returns integer
language sql immutable set search_path = '' as $$ select 7 $$;

create or replace function app.create_invite(p_place uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_me    uuid := auth.uid();
  v_token text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  -- Only someone who belongs to a place can bring someone else into it.
  if not exists (select 1 from public.place_people
                  where place_id = p_place and profile_id = v_me and left_at is null) then
    raise exception 'not a member of this place';
  end if;

  -- 18 random bytes, url-safe: it goes into a link as /i/<token>.
  v_token := translate(encode(extensions.gen_random_bytes(18), 'base64'), '+/=', '-_');

  insert into public.invites (token_hash, place_id, created_by, expires_at)
  values (encode(extensions.digest(v_token, 'sha256'), 'hex'), p_place, v_me,
          now() + make_interval(days => app.invite_days()));

  return v_token;
end $$;

-- Accepting: you become one of the place's people, and nothing else happens.
-- Returns what the welcome screen needs — the place, and who asked you — which
-- you may know now, because you're one of them.
create or replace function app.accept_invite(p_token text)
returns table (place_id uuid, place_name text, invited_by text)
language plpgsql security definer set search_path = '' as $$
-- The returned columns are named for the client, and PL/pgSQL makes them
-- variables too — which collide with place_people.place_id below. Columns win.
#variable_conflict use_column
declare
  v_me     uuid := auth.uid();
  v_place  uuid;
  v_from   uuid;
  v_next   uuid;
  v_hops   integer := 0;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  update public.invites i
     set uses = i.uses + 1
   where i.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
     and i.expires_at > now()
  returning i.place_id, i.created_by into v_place, v_from;

  if v_place is null then raise exception 'invite not found or expired'; end if;

  -- A place merged since the invite was sent: follow it, as a card would.
  loop
    select p.merged_into into v_next from public.places p where p.id = v_place;
    exit when v_next is null;
    v_place := v_next;
    v_hops := v_hops + 1;
    if v_hops > 16 then raise exception 'merge chain too deep'; end if;
  end loop;

  insert into public.place_people (place_id, profile_id)
  values (v_place, v_me)
  on conflict (place_id, profile_id) do update set left_at = null;

  return query
    select p.id, p.name, pr.display_name
      from public.places p
      left join public.profiles pr on pr.id = v_from
     where p.id = v_place;
end $$;

revoke all on function app.invite_days(), app.create_invite(uuid), app.accept_invite(text) from public;
grant execute on function app.create_invite(uuid), app.accept_invite(text) to authenticated;

-- The wrappers PostgREST serves (see 0005).
create or replace function public.create_invite(p_place uuid)
returns text language sql security invoker set search_path = '' as $$
  select app.create_invite(p_place)
$$;

create or replace function public.accept_invite(p_token text)
returns table (place_id uuid, place_name text, invited_by text)
language sql security invoker set search_path = '' as $$
  select * from app.accept_invite(p_token)
$$;

revoke all on function public.create_invite(uuid), public.accept_invite(text) from public, anon;
grant execute on function public.create_invite(uuid), public.accept_invite(text) to authenticated;
