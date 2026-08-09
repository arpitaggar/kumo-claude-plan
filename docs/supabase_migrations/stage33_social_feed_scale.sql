-- =============================================================================
-- Stage 33 — Social feed scalability pass (2026-08-09 scalability audit
-- remediation, see docs/SCALABILITY_AUDIT.md SCALE-001/003/004/008).
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- [SCALE-001] Hot-row like counter.
--
-- sync_post_like_count() ran a synchronous `UPDATE itinerary_posts SET
-- like_count = like_count + 1 WHERE id = ...` on every single like/unlike —
-- every concurrent writer to one popular post's row serializes on that row's
-- lock, and each write leaves a new dead tuple for autovacuum to reclaim,
-- exactly on the row getting the most attention. Fix: stop maintaining a
-- counter column at all — count post_likes rows at read time instead (the
-- Flutter client now uses PostgREST's embedded-resource count,
-- `.select('*, post_likes(count)')`).
-- -----------------------------------------------------------------------------

drop trigger if exists post_likes_sync_count on public.post_likes;
drop function if exists public.sync_post_like_count();

alter table public.itinerary_posts drop column if exists like_count;

-- Read-time counting needs (user_id, created_at) — post_likes' existing
-- primary key is (post_id, user_id), which doesn't help a user_id-first
-- query. Also backs the new rate-limit trigger below.
create index if not exists post_likes_user_id_created_at_idx
  on public.post_likes (user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- [SCALE-003] No rate limiting on likes/follows/posts.
--
-- These are direct client inserts through PostgREST — unlike
-- generate-itinerary/inbound-trip-email, there's no Edge Function
-- intermediary to check a rate limit in application code, so the only
-- server-side place to guard them is a BEFORE INSERT trigger. Thresholds are
-- deliberately generous (a real user double-tapping likes down a fast-
-- scrolling feed can easily hit a dozen/minute) — this is anti-spam, not a
-- pacing mechanism.
-- -----------------------------------------------------------------------------

create or replace function public.check_post_likes_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*) from public.post_likes
    where user_id = new.user_id and created_at > now() - interval '1 minute'
  ) >= 60 then
    raise exception 'Rate limit exceeded: too many likes in a short time. Please slow down.';
  end if;
  return new;
end;
$$;

drop trigger if exists post_likes_rate_limit on public.post_likes;

create trigger post_likes_rate_limit
  before insert on public.post_likes
  for each row execute function public.check_post_likes_rate_limit();

create or replace function public.check_follows_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- follows' primary key (follower_id, followee_id) already leads with
  -- follower_id, so this filter is index-backed without a new index.
  if (
    select count(*) from public.follows
    where follower_id = new.follower_id and created_at > now() - interval '1 minute'
  ) >= 30 then
    raise exception 'Rate limit exceeded: too many follows in a short time. Please slow down.';
  end if;
  return new;
end;
$$;

drop trigger if exists follows_rate_limit on public.follows;

create trigger follows_rate_limit
  before insert on public.follows
  for each row execute function public.check_follows_rate_limit();

create or replace function public.check_itinerary_posts_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- itinerary_posts_author_id_idx (author_id, created_at desc), stage22,
  -- already backs this filter — no new index needed.
  if (
    select count(*) from public.itinerary_posts
    where author_id = new.author_id and created_at > now() - interval '1 hour'
  ) >= 20 then
    raise exception 'Rate limit exceeded: too many trips published in a short time. Please slow down.';
  end if;
  return new;
end;
$$;

drop trigger if exists itinerary_posts_rate_limit on public.itinerary_posts;

create trigger itinerary_posts_rate_limit
  before insert on public.itinerary_posts
  for each row execute function public.check_itinerary_posts_rate_limit();

-- -----------------------------------------------------------------------------
-- [SCALE-008] Explore search only ever searched the 50 most recent posts —
-- a client-side substring filter applied after a fixed-size fetch, so
-- searching "Tokyo" never found an older Tokyo post once 50 newer posts by
-- other authors existed. This was a functional gap, not just a performance
-- one, even at today's data volume.
--
-- Fix: pg_trgm + GIN indexes so `ilike '%term%'` searches the whole table
-- server-side. Chosen over tsvector/full-text search specifically to keep
-- the same substring-match UX (partial-word matches like "Chi" -> "Chiang")
-- rather than switch to word/stem-based matching.
-- -----------------------------------------------------------------------------

create extension if not exists pg_trgm;

create index if not exists itinerary_posts_title_trgm_idx
  on public.itinerary_posts using gin (title gin_trgm_ops);

create index if not exists itinerary_posts_description_trgm_idx
  on public.itinerary_posts using gin (description gin_trgm_ops);
