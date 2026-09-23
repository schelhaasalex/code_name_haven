#!/usr/bin/env bash
# Applies the migrations to a scratch Postgres and runs the assertions.
# Requires a running local Postgres; set PGHOST/PGPORT/PGUSER to reach it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="${RECLAIM_TEST_DB:-reclaim_test}"

psql -q -c "drop database if exists $DB" -c "create database $DB"

# Supabase ships these roles; a bare Postgres does not. `anon` matters as much
# as `authenticated` here — 0002 revokes the default grants from BOTH, and the
# assertion that anon holds nothing in public is the one that caught a live
# hole on the hosted project (schema review, finding 13).
psql -q -d "$DB" -c "do \$\$ begin
  if not exists (select 1 from pg_roles where rolname='authenticated')
  then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='anon')
  then create role anon nologin; end if; end \$\$;"

# Every migration, in order. Leaving the last two out would mean the public
# wrappers the client actually calls are the least-tested thing in the project.
psql -v ON_ERROR_STOP=1 -q -d "$DB" \
  -f "$ROOT/supabase/tests/00_local_auth_stub.sql" \
  -f "$ROOT/supabase/tests/00_local_realtime_stub.sql" \
  -f "$ROOT/supabase/migrations/0001_init.sql" \
  -f "$ROOT/supabase/migrations/0002_rls.sql" \
  -f "$ROOT/supabase/migrations/0003_api.sql" \
  -f "$ROOT/supabase/migrations/0004_function_search_path.sql" \
  -f "$ROOT/supabase/migrations/0005_public_api.sql" \
  -f "$ROOT/supabase/migrations/0006_realtime_auth.sql" \
  -f "$ROOT/supabase/migrations/0007_move_evening.sql" \
  -f "$ROOT/supabase/migrations/0008_invites.sql" \
  -f "$ROOT/supabase/migrations/0009_has_company.sql" \
  -f "$ROOT/supabase/migrations/0010_nearby.sql" \
  -f "$ROOT/supabase/migrations/0011_my_evenings.sql" \
  -f "$ROOT/supabase/migrations/0012_retroactive_cap.sql"

psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$ROOT/supabase/tests/01_schema_test.sql"
