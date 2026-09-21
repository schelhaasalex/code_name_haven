-- Reclaim — who may use a Realtime channel.
--
-- Until this, the ceremony ran on PUBLIC broadcast channels: anyone holding
-- the publishable key — which ships inside the app — could subscribe to
-- `gathering:<id>` or `place:<id>` and hear who set their phone down and
-- when, names included. Row level security never saw it, because public
-- channels don't consult the database. That is rule 1 broken by a side door.
--
-- Private channels ask `realtime.messages` instead: on join, Realtime sets
-- `realtime.topic` and checks whether this person may SELECT (listen) or
-- INSERT (send). The answer is the same one the rest of the schema gives:
--
--   gathering:<id>  you have a session in that gathering
--   place:<id>      you belong to that place and haven't left
--
-- Both are the existing helpers from 0002, so a channel can never be wider
-- than the tables behind it.
--
-- A public channel with the same topic is a DIFFERENT channel — Realtime
-- passes nothing between them — so once the client joins privately, nothing
-- it says reaches a public listener. The project's "Allow public access"
-- setting (Realtime → Settings) is a second line on top: off, it refuses
-- public channels outright. (The copy of this migration applied on
-- 2026-09-21 said the setting was the lock; only this comment differs.)

-- Topics are compared in lowercase. Swift's `UUID.uuidString` is uppercase and
-- Postgres prints uuids in lowercase, so an exact comparison would refuse
-- every join — silently, as a channel that never hears anything.
--
-- Text comparison rather than a cast: a malformed topic is refused, not an
-- error inside a policy.
create or replace function app.may_use_topic(p_topic text)
returns boolean
language sql stable set search_path = ''
as $$
  select case
    when lower(p_topic) like 'gathering:%' then exists (
      select 1 from app.my_gathering_ids() g
       where 'gathering:' || g::text = lower(p_topic))
    when lower(p_topic) like 'place:%' then exists (
      select 1 from app.my_place_ids() p
       where 'place:' || p::text = lower(p_topic))
    else false
  end
$$;

revoke all on function app.may_use_topic(text) from public;
grant execute on function app.may_use_topic(text) to authenticated;

-- Broadcast only. Presence is not used, and a policy that allowed it would
-- be a roster of who is connected — the thing rule 3 says the app never has.
create policy reclaim_broadcast_listen on realtime.messages
  for select to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and app.may_use_topic(realtime.topic())
  );

create policy reclaim_broadcast_send on realtime.messages
  for insert to authenticated
  with check (
    realtime.messages.extension = 'broadcast'
    and app.may_use_topic(realtime.topic())
  );

-- No policy for anon: there is no unauthenticated surface in this app (0002).
