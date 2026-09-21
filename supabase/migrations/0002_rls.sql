-- Reclaim — row level security.
--
-- The load-bearing decision here is that OTHER PEOPLE'S SESSION ROWS ARE NEVER
-- READABLE. Screen 10 promises "they see that you were there, never how often
-- you weren't". RLS cannot express "readable in aggregate but not enumerable",
-- so if co-present users could select each other's sessions, anyone with the
-- anon key could enumerate a person's entire history and the promise is a lie.
-- Co-presence is therefore exposed only through the security-definer functions
-- in 0003, which return the aggregate and nothing else.
--
-- The second thing to know: every membership test goes through a
-- SECURITY DEFINER helper. A policy on place_people that itself queries
-- place_people recurses infinitely — the classic footgun with this shape.

-- ------------------------------------------------------------------ helpers

create or replace function app.my_place_ids()
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select pp.place_id
    from public.place_people pp
   where pp.profile_id = auth.uid()
     and pp.left_at is null
$$;

create or replace function app.my_gathering_ids()
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select s.gathering_id
    from public.sessions s
   where s.profile_id = auth.uid()
$$;

revoke all on function app.my_place_ids()     from public;
revoke all on function app.my_gathering_ids() from public;
grant execute on function app.my_place_ids()     to authenticated;
grant execute on function app.my_gathering_ids() to authenticated;

-- ----------------------------------------------------------------- profiles

alter table profiles enable row level security;

create policy profiles_select_own on profiles
  for select using (id = auth.uid());

create policy profiles_insert_own on profiles
  for insert with check (id = auth.uid());

create policy profiles_update_own on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

create policy profiles_delete_own on profiles
  for delete using (id = auth.uid());

-- Other people's display names come from app.gathering_members / app.place_members,
-- never from selecting this table.

-- ------------------------------------------------------------------- places

alter table places enable row level security;

create policy places_select_member on places
  for select using (id in (select app.my_place_ids()));

create policy places_insert_self on places
  for insert with check (created_by = auth.uid());

create policy places_update_owner on places
  for update using (created_by = auth.uid()) with check (created_by = auth.uid());

-- No delete policy: places are not deleted, they are merged (see app.merge_places).

-- -------------------------------------------------------------- place_people

alter table place_people enable row level security;

-- You can see and manage your own membership rows only. Who else has been to a
-- place comes from app.place_members, which is security definer — a policy that
-- read other rows of this table from a policy ON this table would recurse.
create policy place_people_select_own on place_people
  for select using (profile_id = auth.uid());

create policy place_people_insert_own on place_people
  for insert with check (profile_id = auth.uid());

create policy place_people_update_own on place_people
  for update using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- --------------------------------------------------------------- gatherings

alter table gatherings enable row level security;

create policy gatherings_select_member on gatherings
  for select using (id in (select app.my_gathering_ids()));

create policy gatherings_insert_member on gatherings
  for insert with check (
    started_by = auth.uid()
    and (place_id is null or place_id in (select app.my_place_ids()))
  );

create policy gatherings_update_member on gatherings
  for update using (id in (select app.my_gathering_ids()))
          with check (id in (select app.my_gathering_ids()));

-- ----------------------------------------------------------------- sessions

alter table sessions enable row level security;

-- Own rows only. This is the visibility promise, enforced at the database.
create policy sessions_select_own on sessions
  for select using (profile_id = auth.uid());

create policy sessions_insert_own on sessions
  for insert with check (profile_id = auth.uid());

-- Only a live session may be edited, and only by its owner. A finished session
-- is a fact; correcting one means deleting it (screen 13's "remove it"), not
-- editing the duration upward.
create policy sessions_update_own_live on sessions
  for update using (profile_id = auth.uid() and ended_at is null)
          with check (profile_id = auth.uid());

create policy sessions_delete_own on sessions
  for delete using (profile_id = auth.uid());

-- --------------------------------------------------------------- privileges

grant usage on schema app to authenticated;

-- Grants are deliberately narrow. Anything that creates or mutates shared state
-- goes through the RPCs in 0003, which are the only place the invariants
-- (one open gathering per place, credit at the cap, qualifying on end) are
-- enforced. RLS then acts as a second line rather than the only one.

grant select, insert, update on profiles to authenticated;

-- join_secret_hash must never reach a client. A table-level SELECT grant covers
-- every column and a column-level REVOKE cannot carve one back out of it, so
-- the grant itself has to be column-scoped. Resolution goes through
-- app.resolve_place, which is security definer.
grant select (id, name, handle, created_by, merged_into, created_at)
  on places to authenticated;
grant update (name) on places to authenticated;
-- No insert: places are created by app.create_place.
-- No delete: places are merged, never deleted.

grant select, insert on place_people to authenticated;
grant update (left_at) on place_people to authenticated;

grant select on gatherings to authenticated;
-- No insert or update: gatherings are opened and closed by the RPCs, which is
-- what keeps the one-open-gathering-per-place invariant meaningful.

grant select, delete on sessions to authenticated;
-- No insert or update: app.start_or_join and app.end_session own the lifecycle.
-- Delete stays, because screen 13 offers "that wasn't a real one — remove it",
-- and the only correction the product ever offers is downward.
