-- LOCAL TEST ONLY. Supabase provides auth.users and auth.uid() in the real
-- project; this stub lets the migrations run against a bare Postgres so the
-- DDL, constraints, policies and functions can be executed and asserted.
-- Never apply this file to a Supabase project.
create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

-- convenience for tests: become a given user
create or replace function auth.login(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claim.sub', p_id::text, false)
$$;

create or replace function auth.logout() returns void
language sql as $$
  select set_config('request.jwt.claim.sub', '', false)
$$;
