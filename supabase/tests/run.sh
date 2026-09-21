#!/usr/bin/env bash
# Applies the migrations to a scratch Postgres and runs the assertions.
# Requires a running local Postgres; set PGHOST/PGPORT/PGUSER to reach it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="${RECLAIM_TEST_DB:-reclaim_test}"

psql -q -c "drop database if exists $DB" -c "create database $DB"
psql -q -d "$DB" -c "do \$\$ begin
  if not exists (select 1 from pg_roles where rolname='authenticated')
  then create role authenticated nologin; end if; end \$\$;"

psql -v ON_ERROR_STOP=1 -q -d "$DB" \
  -f "$ROOT/supabase/tests/00_local_auth_stub.sql" \
  -f "$ROOT/supabase/migrations/0001_init.sql" \
  -f "$ROOT/supabase/migrations/0002_rls.sql" \
  -f "$ROOT/supabase/migrations/0003_api.sql"

psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$ROOT/supabase/tests/01_schema_test.sql"
