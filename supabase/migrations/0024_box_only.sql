-- 0024: what the box-only app no longer calls.
--
-- Since 2026-11-06 the box is the only switch (CLAUDE.md rule 4). Every
-- function dropped here was a way into an evening, or a screen, that has gone
-- from the app — and every one was still callable by any signed-in account.
-- `record_retroactive` could add evenings nobody spent at a box to the box's
-- totals; `join_nearby` and `accept_invite` could put a phone into an evening
-- it was never set down in.
--
-- APPLY ONLY ONCE NO BUILD THAT CALLS THESE IS IN ANYONE'S HANDS — TestFlight
-- included. A build from before 0023's release asks `gathering_members` how
-- many are in the box, and would get a 404 where the count was.
--
-- Kept: `app.resolve_place` (dock_place reads a card through it) and
-- `app.create_place` (the tests make places with it; nothing exposes it).
-- The columns nothing writes any more — profiles' name and nudge settings,
-- sessions.retroactive — stay: old rows still carry them, and dropping a
-- column is not worth an outage nobody would notice the benefit of.

-- ------------------------------------------------------- what goes

-- Every overload, by name, in both schemas: the public wrapper a client could
-- call, and the app function behind it.
do $$
declare f regprocedure;
begin
  for f in
    select p.oid::regprocedure
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where (n.nspname = 'public' and p.proname in (
              'gathering_members', 'create_place', 'resolve_place',
              'record_retroactive', 'my_rhythm', 'name_somewhere', 'merge_places',
              'move_evening', 'create_invite', 'accept_invite', 'has_company',
              'open_nearby', 'nearby_offer', 'join_nearby'))
        or (n.nspname = 'app' and p.proname in (
              'gathering_members',
              'record_retroactive', 'my_rhythm', 'name_somewhere', 'merge_places',
              'move_evening', 'create_invite', 'accept_invite', 'has_company',
              'open_nearby', 'nearby_offer', 'join_nearby'))
  loop
    execute format('drop function %s', f);
  end loop;
end $$;

-- Invites and the over-the-air keys: nothing makes or reads either now.
drop table public.nearby_keys;
drop table public.invites;
