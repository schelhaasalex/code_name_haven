-- LOCAL TEST ONLY. Supabase provides the realtime schema in the real project;
-- this stub lets 0006's policies run against a bare Postgres. Never apply this
-- file to a Supabase project.
--
-- Shaped after the hosted project, read on 2026-09-21: row level security on
-- and no policies of its own, INSERT/SELECT/UPDATE granted to both anon and
-- authenticated, and realtime.topic() reading a setting. The hosted table is
-- partitioned; nothing a policy can see depends on that, so this one isn't.
create schema if not exists realtime;

create table if not exists realtime.messages (
  id uuid default gen_random_uuid(),
  topic text not null,
  extension text not null,
  payload jsonb,
  event text,
  private boolean default false,
  inserted_at timestamp default now(),
  updated_at timestamp default now()
);

alter table realtime.messages enable row level security;

grant usage on schema realtime to anon, authenticated;
grant insert, select, update on realtime.messages to anon, authenticated;

-- Realtime sets this per channel join, then asks the table whether this
-- person may read (subscribe) or insert (send) on it.
create or replace function realtime.topic() returns text
language sql stable as $$
  select nullif(current_setting('realtime.topic', true), '')::text
$$;
