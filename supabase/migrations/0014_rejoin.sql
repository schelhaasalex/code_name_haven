-- Reclaim — stepping out of an evening, and coming back to it.
--
-- One row per person per gathering was the rule, and start_or_join kept it
-- with ON CONFLICT ... DO UPDATE: a second tap was the same session. It also
-- meant that someone who ended their evening while others were still in it,
-- and then came back, got their ENDED row handed back as a success. Nothing
-- started. Found on a phone set into the box: the evening there was still
-- open, because someone else was in it, and the phone's own minute-long test
-- from earlier that afternoon was all start_or_join would give it.
--
-- Coming back is now a new stretch of the same evening. The time away is not
-- credited (stitching the stretches together would credit the gap), the
-- person is listed once however many stretches they have, and the stretches
-- together decide whether the evening counted. Two taps while running are
-- still one stretch: sessions_one_live_per_profile guarantees it.
--
-- And the auto-close that 0003 wrote has never run on the hosted project:
-- nothing scheduled it. An evening there sat "live" for seventeen hours.

drop index if exists public.sessions_one_per_gathering_member;

-- ------------------------------------------------------------- start or join

create or replace function app.start_or_join(
  p_place  uuid default null,
  p_source text default 'app',
  p_tz     text default 'UTC')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_me        uuid := auth.uid();
  v_gathering uuid;
  v_session   uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  if p_place is not null then
    select id into v_gathering
      from public.gatherings
     where place_id = p_place and ended_at is null
     order by started_at
     limit 1;
  end if;

  if v_gathering is null then
    begin
      insert into public.gatherings (place_id, started_by)
      values (p_place, v_me)
      returning id into v_gathering;
    exception when unique_violation then
      select id into v_gathering
        from public.gatherings
       where place_id = p_place and ended_at is null
       limit 1;
    end;
  end if;

  -- Already running here: the second tap is the same stretch.
  select id into v_session
    from public.sessions
   where gathering_id = v_gathering and profile_id = v_me and ended_at is null;

  if v_session is not null then
    update public.sessions set source = p_source where id = v_session;
  else
    begin
      insert into public.sessions (profile_id, gathering_id, local_date, source)
      values (v_me, v_gathering, (now() at time zone p_tz)::date, p_source)
      returning id into v_session;
    exception when unique_violation then
      -- Two taps racing: the other one's stretch is this one. Running
      -- somewhere else entirely is still an error, as it always was.
      select id into v_session
        from public.sessions
       where gathering_id = v_gathering and profile_id = v_me and ended_at is null;
      if v_session is null then raise; end if;
    end;
  end if;

  if p_place is not null then
    insert into public.place_people (place_id, profile_id)
    values (p_place, v_me)
    on conflict (place_id, profile_id) do update set left_at = null;
  end if;

  return v_session;
end $$;

-- -------------------------------------------------------------- end a session

create or replace function app.end_session(p_session uuid default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_me       uuid := auth.uid();
  v_id       uuid;
  v_gather   uuid;
  v_minutes  integer;
  v_total    integer;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select id into v_id
    from public.sessions
   where profile_id = v_me and ended_at is null
     and (p_session is null or id = p_session)
   limit 1;

  if v_id is null then return null; end if;

  update public.sessions
     set ended_at         = now(),
         duration_minutes = floor(extract(epoch from (now() - started_at)) / 60)::int
   where id = v_id
  returning gathering_id, duration_minutes into v_gather, v_minutes;

  -- Whether the evening counted is a question about the evening, not the
  -- stretch: every stretch of yours in it, together.
  select coalesce(sum(duration_minutes), 0) into v_total
    from public.sessions
   where gathering_id = v_gather and profile_id = v_me and ended_at is not null;

  update public.sessions
     set qualifying = v_total >= app.qualifying_minutes()
   where gathering_id = v_gather and profile_id = v_me and ended_at is not null;

  -- Close the gathering once nobody in it is still live, so the place stops
  -- reading as "happening now" and the partial unique index frees up.
  update public.gatherings g
     set ended_at = now()
   where g.id = v_gather
     and g.ended_at is null
     and not exists (select 1 from public.sessions s
                      where s.gathering_id = g.id and s.ended_at is null);

  return v_minutes;
end $$;

-- ----------------------------------------------------------- who is in it

-- One row per person, however many stretches. still_live if any of them is.
create or replace function app.gathering_members(p_gathering uuid)
returns table (profile_id uuid, display_name text, still_live boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.sessions s
                  where s.gathering_id = p_gathering and s.profile_id = auth.uid())
  then
    raise exception 'not a member of this gathering';
  end if;

  return query
    select s.profile_id, pr.display_name, bool_or(s.ended_at is null)
      from public.sessions s
      join public.profiles pr on pr.id = s.profile_id
     where s.gathering_id = p_gathering
     group by s.profile_id, pr.display_name
     order by min(s.started_at);
end $$;

-- ------------------------------------------------------- moving an evening

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
    -- Into an evening you were in earlier tonight: this is another stretch of
    -- it, beside the earlier one. 0007 refused here, because stitching the two
    -- together would have credited the gap; separate stretches don't.
    update public.sessions set gathering_id = v_to where id = v_session;
    if v_others = 0 and not exists (select 1 from public.sessions where gathering_id = v_from) then
      delete from public.gatherings where id = v_from;
    end if;
  end if;

  insert into public.place_people (place_id, profile_id)
  values (p_place, v_me)
  on conflict (place_id, profile_id) do update set left_at = null;

  return v_to;
end $$;

-- ------------------------------------------------------------ the offer

-- No offer while you're in it; once you've stepped out, a table you were at
-- earlier is a table you can come back to. People, not stretches.
create or replace function app.nearby_offer(p_token text)
returns table (gathering uuid, people integer, since timestamptz)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_me     uuid := auth.uid();
  v_id     uuid;
  v_since  timestamptz;
  v_people integer;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select g.id, g.started_at into v_id, v_since
    from public.nearby_keys k
    join public.gatherings g on g.id = k.gathering_id
   where k.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
     and k.expires_at > now()
     and g.ended_at is null;

  if v_id is null then return; end if;
  if exists (select 1 from public.sessions s
              where s.gathering_id = v_id and s.profile_id = v_me
                and s.ended_at is null) then return; end if;

  select count(distinct s.profile_id) into v_people
    from public.sessions s where s.gathering_id = v_id;

  return query select v_id, v_people, v_since;
end $$;

-- ------------------------------------------------------------- auto-close

-- Every five minutes, where pg_cron exists — the hosted project. A bare local
-- Postgres has no pg_cron, and the tests call app.auto_close_stale directly.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.unschedule(jobid) from cron.job where jobname = 'auto-close-stale';
    perform cron.schedule('auto-close-stale', '*/5 * * * *', 'select app.auto_close_stale()');
  else
    raise notice 'pg_cron is not available here; auto-close is not scheduled';
  end if;
end $$;
