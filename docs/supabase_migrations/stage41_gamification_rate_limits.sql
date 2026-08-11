-- =============================================================================
-- Stage 41 — Gamification anti-abuse: rate-limit XP from trip creation and
-- completion.
--
-- Found during a follow-up audit of stage40. award_xp_on_trip_created and
-- award_xp_on_trip_completed had no throttle at all, unlike every other XP
-- source — post publish/like/follow/comment all sit on tables that already
-- have their own rate-limit triggers (stage33/34), but `itineraries` has no
-- rate limit anywhere in this schema. A scripted client could spam cheap
-- trip creation (+10 XP each) or create-then-immediately-complete
-- (+40 XP each) with nothing to stop it. This is exactly the same reasoning
-- stage40 already used to deliberately exclude expenses as an XP source
-- ("expenses have no rate limit anywhere, trivially farmable") — it just
-- wasn't applied consistently to trip creation/completion at the time.
-- Unlike expenses, trip creation/completion are meaningful enough
-- milestones to be worth keeping as XP sources, so this rate-limits the
-- award instead of removing the source entirely.
--
-- Deliberately does NOT add a rate limit to the itineraries table itself —
-- creating or completing a trip stays completely unrestricted for every
-- user, gamification or not. Only the XP *award* is throttled, inside the
-- two trigger functions below (CREATE OR REPLACE against the exact
-- functions stage40 created) — no RLS or trigger on `itineraries` changes.
--
-- Safe to re-run: uses CREATE OR REPLACE.
-- =============================================================================

create or replace function public.award_xp_on_trip_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*) from public.xp_events
    where user_id = new.owner_id
      and source_type = 'trip_created'
      and created_at > now() - interval '1 hour'
  ) >= 5 then
    return new;
  end if;

  insert into public.xp_events (user_id, amount, reason, source_type, source_id)
  values (new.owner_id, 10, 'Planned a new trip', 'trip_created', new.id::text)
  on conflict (user_id, source_type, source_id) do nothing;
  return new;
end;
$$;

create or replace function public.award_xp_on_trip_completed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*) from public.xp_events
    where user_id = new.owner_id
      and source_type = 'trip_completed'
      and created_at > now() - interval '1 hour'
  ) >= 5 then
    return new;
  end if;

  insert into public.xp_events (user_id, amount, reason, source_type, source_id)
  values (new.owner_id, 30, 'Completed a trip', 'trip_completed', new.id::text)
  on conflict (user_id, source_type, source_id) do nothing;
  return new;
end;
$$;
