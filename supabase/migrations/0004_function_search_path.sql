-- Pin search_path on the three constant functions.
--
-- Found by Supabase's own database linter (0011_function_search_path_mutable)
-- after applying 0001–0003 to a hosted project — the local scratch Postgres in
-- supabase/tests has no such linter, so this is one the offline run could not
-- have caught.
--
-- These three take no tables and reference nothing schema-qualified, so the
-- practical risk is small. But "small" is not a reason to leave a mutable
-- search_path on a function other functions call, and every other function in
-- this schema already sets it. Consistency here is cheaper than a judgement
-- call each time someone adds one.

create or replace function app.qualifying_minutes() returns integer
language sql immutable set search_path = '' as $$ select 15 $$;

create or replace function app.auto_close_minutes() returns integer
language sql immutable set search_path = '' as $$ select 180 $$;

create or replace function app.place_stage(p_evenings integer)
returns text language sql immutable set search_path = '' as $$
  select case
    when p_evenings >= 50 then 'a landmark'
    when p_evenings >= 20 then 'a reclaim house'
    when p_evenings >= 5  then 'a regular table'
    else 'new here'
  end
$$;

revoke all on function app.place_stage(integer) from public;
grant execute on function app.place_stage(integer) to authenticated;
