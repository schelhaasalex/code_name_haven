-- Reclaim — scanning a card after you've already set your phone down.
--
-- Screen 3 promised "if there's a card on the table, scan it and this becomes
-- that place", and nothing could keep it: start_or_join would try to open a
-- second live evening, and sessions_one_live_per_profile rightly refused.
--
-- It matters beyond tidiness. A host who started as Somewhere sits in a
-- placeless gathering nobody can join, so a friend who arrives and taps the
-- card opens a SEPARATE evening at the same table — and the two never see
-- each other. Moving the host's evening to the place is what puts them
-- together.
--
-- What moves is only where the evening is. Your session keeps its own
-- started_at and local_date, so no credit changes, in either direction.

create or replace function app.move_evening(p_place uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me         uuid := auth.uid();
  v_session    uuid;
  v_from       uuid;
  v_from_place uuid;
  v_to         uuid;
  v_others     integer;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.places where id = p_place and merged_into is null) then
    raise exception 'place not found';
  end if;

  select s.id, s.gathering_id, g.place_id
    into v_session, v_from, v_from_place
    from public.sessions s
    join public.gatherings g on g.id = s.gathering_id
   where s.profile_id = v_me and s.ended_at is null
     for update of s;
  if v_session is null then raise exception 'no live session'; end if;

  -- Already here: nothing to do, and nothing to announce.
  if v_from_place is not distinct from p_place then return v_from; end if;

  select id into v_to
    from public.gatherings
   where place_id = p_place and ended_at is null
   limit 1;

  -- Anyone else in the evening you're leaving, ended or not. Their rows keep
  -- it alive; with nobody else, it was only ever yours.
  select count(*) into v_others
    from public.sessions
   where gathering_id = v_from and profile_id <> v_me;

  if v_to is null and v_others = 0 then
    -- Nothing open there, and this evening is only yours: it becomes the
    -- place's. The unique index settles a race with someone starting there.
    begin
      update public.gatherings set place_id = p_place where id = v_from;
      v_to := v_from;
    exception when unique_violation then
      select id into v_to from public.gatherings
       where place_id = p_place and ended_at is null limit 1;
    end;
  elsif v_to is null then
    begin
      insert into public.gatherings (place_id, started_by)
      values (p_place, v_me) returning id into v_to;
    exception when unique_violation then
      select id into v_to from public.gatherings
       where place_id = p_place and ended_at is null limit 1;
    end;
  end if;

  if v_to <> v_from then
    -- Already in that evening earlier tonight, and ended it: one row per
    -- person per gathering, and stitching the two together would credit the
    -- gap between them. Refuse plainly rather than guess.
    if exists (select 1 from public.sessions
                where gathering_id = v_to and profile_id = v_me) then
      raise exception 'already in that evening earlier';
    end if;
    update public.sessions set gathering_id = v_to where id = v_session;
    if v_others = 0 then
      delete from public.gatherings where id = v_from;
    end if;
  end if;

  insert into public.place_people (place_id, profile_id)
  values (p_place, v_me)
  on conflict (place_id, profile_id) do update set left_at = null;

  return v_to;
end $$;

revoke all on function app.move_evening(uuid) from public;
grant execute on function app.move_evening(uuid) to authenticated;

-- The wrapper PostgREST serves (see 0005).
create or replace function public.move_evening(p_place uuid)
returns uuid language sql security invoker set search_path = '' as $$
  select app.move_evening(p_place)
$$;

revoke all on function public.move_evening(uuid) from public, anon;
grant execute on function public.move_evening(uuid) to authenticated;
