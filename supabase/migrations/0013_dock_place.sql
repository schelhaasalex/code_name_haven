-- Reclaim — a box is a place that already has its card.
--
-- A card's secret is minted by the phone that makes the place, so no two have
-- ever met. A box is different: its four slot tags are written before anyone
-- owns it, all carrying one secret, and the first phone set into it is the one
-- that makes its place. Two people doing that in the same breath — which is
-- the box working as intended — would each have made one, and
-- `resolve_place` would then answer with whichever it found first.
--
-- So the secret is unique, and `dock_place` finds the box's place or makes it
-- in one statement. A handle that happens to be taken comes back as null, and
-- the phone asks again with another: the word list lives in Swift (`Handle`).

create unique index if not exists places_join_secret_hash_key
  on public.places (join_secret_hash);

create or replace function app.dock_place(p_secret text, p_handle text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  v_id := app.resolve_place(p_secret);
  if v_id is not null then
    return v_id;
  end if;

  -- No conflict target: losing the race on the secret and drawing a handle
  -- someone else has are both "not this time", and the lookup after says which.
  insert into public.places (handle, join_secret_hash, created_by)
  values (p_handle, encode(extensions.digest(p_secret, 'sha256'), 'hex'), v_me)
  on conflict do nothing
  returning id into v_id;

  if v_id is null then
    return app.resolve_place(p_secret);
  end if;

  insert into public.place_people (place_id, profile_id) values (v_id, v_me);
  return v_id;
end $$;

revoke all on function app.dock_place(text, text) from public;
grant execute on function app.dock_place(text, text) to authenticated;

-- The wrapper PostgREST serves (see 0005).
create or replace function public.dock_place(p_secret text, p_handle text)
returns uuid language sql security invoker set search_path = '' as $$
  select app.dock_place(p_secret, p_handle)
$$;

revoke all on function public.dock_place(text, text) from public, anon;
grant execute on function public.dock_place(text, text) to authenticated;
