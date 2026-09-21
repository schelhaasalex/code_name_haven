-- Reclaim — core schema.
--
-- Shape notes, so nobody has to re-derive them:
--   * A gathering owns the place. Sessions do NOT carry place_id, because two
--     copies of the same fact can disagree. A solo session is a gathering of one.
--   * local_date lives on the session (per person, in their timezone at start).
--     It is what rhythm maths uses, and COUNT(DISTINCT local_date) is what makes
--     a five-person dinner count as one evening rather than five.
--   * A place's handle is a display label. The join credential is a hashed
--     secret that lives in the NFC tag and the QR and is never selectable.

-- pgcrypto must live in `extensions`, which is where Supabase puts it. Every
-- function below sets an empty search_path (so a hostile search_path cannot
-- redirect a call), which means digest() has to be schema-qualified, which
-- means the schema has to be predictable.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create schema if not exists app;

-- ---------------------------------------------------------------- constants
-- These are product rules, not user configuration. Screen 16 states them as
-- facts. Keeping them as functions means one definition, callable from SQL.

create or replace function app.qualifying_minutes() returns integer
language sql immutable as $$ select 15 $$;

create or replace function app.auto_close_minutes() returns integer
language sql immutable as $$ select 180 $$;

-- ----------------------------------------------------------------- profiles

create table profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  nudge_enabled boolean  not null default true,
  nudge_hour    smallint not null default 19 check (nudge_hour between 0 and 23),
  created_at    timestamptz not null default now()
);

comment on column profiles.display_name is
  'Self-chosen. Seeded from Sign in with Apple on first authorization ever — '
  'Apple hands it over exactly once, so capture it then. Nullable because the '
  'user may withhold it. This is how someone becomes "Dad": he picked it.';

-- ------------------------------------------------------------------- places

create table places (
  id               uuid primary key default gen_random_uuid(),
  name             text,
  handle           text not null unique,
  join_secret_hash text not null,
  created_by       uuid references profiles(id) on delete set null,
  merged_into      uuid references places(id) on delete set null,
  created_at       timestamptz not null default now(),
  constraint places_handle_format  check (handle ~ '^[a-z]+-[a-z]+$'),
  constraint places_no_self_merge  check (merged_into is distinct from id)
);

comment on column places.name is
  'Nullable and stays that way. An unnamed place is valid; sessions with no '
  'place at all are also valid and surface as "Somewhere".';
comment on column places.handle is
  'Generated word pair, e.g. amber-otter. Printed on the card, sayable down a '
  'phone. DISPLAY ONLY — never sufficient to join.';
comment on column places.merged_into is
  'Set when this place is merged into another. Old cards keep resolving via '
  'app.resolve_place, so merging never bricks a printed tag.';

-- Future: a nullable site_id for depth-one grouping (rooms in a building).
-- Deliberately not built. Sessions always happen at a leaf, so a parent is
-- only ever a reporting concern and can be added without touching anything here.

create table place_people (
  place_id      uuid not null references places(id)   on delete cascade,
  profile_id    uuid not null references profiles(id) on delete cascade,
  first_seen_at timestamptz not null default now(),
  left_at       timestamptz,
  primary key (place_id, profile_id)
);

comment on column place_people.left_at is
  'Without this a friend''s house you visited once is in your list forever, '
  'and you are in their member list forever.';

-- --------------------------------------------------------------- gatherings

create table gatherings (
  id         uuid primary key default gen_random_uuid(),
  place_id   uuid references places(id)   on delete set null,
  started_by uuid references profiles(id) on delete set null,
  started_at timestamptz not null default now(),
  ended_at   timestamptz,
  created_at timestamptz not null default now(),
  constraint gatherings_time_order check (ended_at is null or ended_at >= started_at)
);

-- THE JOIN RACE FIX. Two people at one table both tap "Set it down" within a
-- couple of seconds, neither having seen the other's broadcast. Without this
-- they create two gatherings and the table disagrees about how many people are
-- in it. The second insert now conflicts and app.start_or_join falls back to
-- joining. NULL place_ids are distinct under a unique index, so solo and
-- "Somewhere" gatherings are unaffected.
create unique index gatherings_one_open_per_place
  on gatherings (place_id)
  where ended_at is null and place_id is not null;

create index gatherings_place_recent on gatherings (place_id, started_at desc);

-- ----------------------------------------------------------------- sessions

create table sessions (
  id               uuid primary key default gen_random_uuid(),
  profile_id       uuid not null references profiles(id)   on delete cascade,
  gathering_id     uuid not null references gatherings(id) on delete cascade,
  started_at       timestamptz not null default now(),
  ended_at         timestamptz,
  duration_minutes integer,
  local_date       date    not null,
  qualifying       boolean not null default false,
  auto_closed      boolean not null default false,
  retroactive      boolean not null default false,
  source           text    not null default 'app',
  puck_id          uuid,
  created_at       timestamptz not null default now(),
  constraint sessions_source_known check (
    source in ('app','tag','control','siri','shortcut','retroactive')),
  constraint sessions_time_order check (ended_at is null or ended_at >= started_at),
  constraint sessions_closed_fields check (
        (ended_at is null     and duration_minutes is null)
     or (ended_at is not null and duration_minutes is not null)),
  -- A live session has not qualified yet. Anything counting evenings must
  -- therefore filter on qualifying and never see half-finished rows.
  constraint sessions_live_not_qualifying check (ended_at is not null or qualifying = false),
  constraint sessions_duration_sane check (duration_minutes is null or duration_minutes >= 0)
);

create unique index sessions_one_live_per_profile
  on sessions (profile_id) where ended_at is null;

create unique index sessions_one_per_gathering_member
  on sessions (gathering_id, profile_id);

create index sessions_profile_date on sessions (profile_id, local_date);
create index sessions_gathering     on sessions (gathering_id);

comment on column sessions.local_date is
  'The calendar date in the user''s own timezone at the moment the session '
  'started, computed at write time. Sessions credit to the day they STARTED, '
  'so one that crosses midnight belongs to the earlier day.';
comment on column sessions.auto_closed is
  'Closed by app.auto_close_stale rather than by a person. Such a session is '
  'credited at the cap, never at the wall-clock time the phone sat there — '
  'otherwise the cheapest strategy in the product is to start one and walk away.';

-- ------------------------------------------- place ownership after deletion
-- The brief: if the owner's account goes, the place survives and ownership
-- falls to whoever has the most evenings there.

create or replace function app.reassign_places_on_profile_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.places p
     set created_by = coalesce(
       -- Whoever has the most evenings here.
       (select s.profile_id
          from public.sessions s
          join public.gatherings g on g.id = s.gathering_id
         where g.place_id = p.id
           and s.profile_id <> old.id
           and s.qualifying
         group by s.profile_id
         order by count(distinct s.local_date) desc, min(s.started_at) asc
         limit 1),
       -- Nobody has qualifying evenings yet: fall back to the longest-standing
       -- member, rather than leaving the place ownerless and unrenameable.
       (select pp.profile_id
          from public.place_people pp
         where pp.place_id = p.id
           and pp.profile_id <> old.id
           and pp.left_at is null
         order by pp.first_seen_at asc
         limit 1))
   where p.created_by = old.id;
  return old;
end $$;

create trigger profiles_reassign_places
  before delete on profiles
  for each row execute function app.reassign_places_on_profile_delete();
