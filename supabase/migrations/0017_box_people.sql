-- Reclaim — reading a box makes you one of its people.
--
-- A box's place used to gain people only by evenings: whoever made it in
-- 0013, and everyone else at their first evening there, through start_or_join.
-- That was enough while a slot's tag was the only thing to read, because the
-- tag starts the evening. The box now also has a code, read with the phone in
-- a hand, that pairs and starts nothing — and a phone that paired by it
-- couldn't see the box it had just paired with: places and place_summary are
-- for a place's people.
--
-- So finding a box is joining it. Someone who had left (left_at) and reads it
-- again is back.

create or replace function app.dock_place(p_secret text, p_handle text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  v_id := app.resolve_place(p_secret);

  if v_id is null then
    -- No conflict target: losing the race on the secret and drawing a handle
    -- someone else has are both "not this time", and the lookup after says which.
    insert into public.places (handle, join_secret_hash, created_by)
    values (p_handle, encode(extensions.digest(p_secret, 'sha256'), 'hex'), v_me)
    on conflict do nothing
    returning id into v_id;

    if v_id is null then
      v_id := app.resolve_place(p_secret);
    end if;
  end if;

  -- Still nothing: the handle was taken. The phone draws another.
  if v_id is null then
    return null;
  end if;

  insert into public.place_people (place_id, profile_id) values (v_id, v_me)
  on conflict (place_id, profile_id) do update set left_at = null;
  return v_id;
end $$;
