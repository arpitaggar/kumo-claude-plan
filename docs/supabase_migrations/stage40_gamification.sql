-- =============================================================================
-- Stage 40 — Gamification: XP, levels, and badges.
--
-- Carried on docs/DEVELOPMENT_ROADMAP.md's "What Remains" table since the
-- original v1.0 brief, deferred as "post-retention-baseline" rather than
-- blocked by anything external (unlike Stripe/B2B-portal/Concierge-AI).
--
-- XP is awarded entirely by triggers on tables that already exist
-- (itinerary_posts, post_likes, follows, post_comments, itineraries) — the
-- exact same shape as public.notifications (stage37). No existing mutation
-- code path changes at all; this migration and the Flutter read-side built
-- on top of it are the whole feature.
--
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. xp_events
--    Append-only ledger — same shape as profile_status (stage21): "current
--    total" is derived (sum(amount)), not a mutable counter column, so there
--    is nothing to keep in sync and every award is individually auditable.
--
--    Anti-cheat is the unique index below, not a rate-limit trigger: source_id
--    is chosen per source table so the same real-world event can never award
--    twice, which closes both the "toggle a trip active/completed to farm XP"
--    vector and the "unlike/relike, unfollow/refollow to farm XP" vector.
--    See the per-trigger comments below for exactly what source_id encodes.
-- -----------------------------------------------------------------------------

create table if not exists public.xp_events (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  amount      int         not null,
  reason      text        not null,
  source_type text        not null check (source_type in (
    'trip_created', 'trip_completed', 'post_published',
    'post_liked', 'follower_gained', 'comment_posted'
  )),
  source_id   text        not null,
  created_at  timestamptz not null default now()
);

create unique index if not exists xp_events_dedup_idx
  on public.xp_events (user_id, source_type, source_id);

create index if not exists xp_events_user_id_created_at_idx
  on public.xp_events (user_id, created_at desc);

alter table public.xp_events enable row level security;

drop policy if exists "xp_events_owner_read" on public.xp_events;

-- No insert/update/delete policy at all, deliberately — every row is
-- written by the SECURITY DEFINER trigger functions below, never by a
-- direct client insert (an RLS table with zero insert policies rejects
-- every client insert attempt outright). Same anti-spoofing shape as
-- public.notifications (stage37): a client can no more award itself XP
-- than it can fabricate a "so-and-so liked your post" notification.
create policy "xp_events_owner_read" on public.xp_events
  for select using (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 2. Triggers — one per source table. All SECURITY DEFINER since the
--    recipient often isn't the row owner (e.g. the liker inserts a
--    post_likes row, but the post's *author* is who earns XP for it).
--
--    Actor-vs-recipient is deliberate, not inconsistent: creating a trip,
--    completing a trip, publishing a post, and commenting reward the person
--    *doing* the thing; being liked or followed rewards the person
--    *receiving* the social validation.
--
--    add_expense_usecase.dart is deliberately NOT wired up here — unlike
--    posts/likes/follows/comments, expenses have no rate limit anywhere in
--    this schema today, so an expense-XP trigger would be trivially
--    farmable by spamming tiny expenses. Revisit only if expenses ever gain
--    a rate limit for other reasons.
-- -----------------------------------------------------------------------------

-- Trip created: source_id = the trip's own id, so re-inserting can't happen
-- (a real primary key) — every trip creation is a genuinely new event.
create or replace function public.award_xp_on_trip_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.xp_events (user_id, amount, reason, source_type, source_id)
  values (new.owner_id, 10, 'Planned a new trip', 'trip_created', new.id::text)
  on conflict (user_id, source_type, source_id) do nothing;
  return new;
end;
$$;

drop trigger if exists itineraries_award_xp_created on public.itineraries;

create trigger itineraries_award_xp_created
  after insert on public.itineraries
  for each row execute function public.award_xp_on_trip_created();

-- Trip completed: fires only when status actually transitions *to*
-- 'completed' (the WHEN clause below skips the trigger body entirely for
-- every other update, so this is cheap). source_id = the trip's own id, so
-- toggling active -> completed -> active -> completed only ever awards once
-- — closes the obvious "flip status back and forth to farm XP" vector.
create or replace function public.award_xp_on_trip_completed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.xp_events (user_id, amount, reason, source_type, source_id)
  values (new.owner_id, 30, 'Completed a trip', 'trip_completed', new.id::text)
  on conflict (user_id, source_type, source_id) do nothing;
  return new;
end;
$$;

drop trigger if exists itineraries_award_xp_completed on public.itineraries;

create trigger itineraries_award_xp_completed
  after update of status on public.itineraries
  for each row
  when (new.status = 'completed' and old.status is distinct from 'completed')
  execute function public.award_xp_on_trip_completed();

-- Post published: source_id = the post's own id.
create or replace function public.award_xp_on_post_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.xp_events (user_id, amount, reason, source_type, source_id)
  values (new.author_id, 15, 'Published a trip', 'post_published', new.id::text)
  on conflict (user_id, source_type, source_id) do nothing;
  return new;
end;
$$;

drop trigger if exists itinerary_posts_award_xp on public.itinerary_posts;

create trigger itinerary_posts_award_xp
  after insert on public.itinerary_posts
  for each row execute function public.award_xp_on_post_published();

-- Post liked: recipient is the post's author, looked up the same way
-- notify_on_post_like (stage37) does. source_id encodes the (post, liker)
-- pair, not just the post — so a *different* liker still awards separately,
-- but the *same* liker toggling like/unlike/relike on the same post only
-- ever awards once.
create or replace function public.award_xp_on_post_liked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _author_id uuid;
begin
  select author_id into _author_id
    from public.itinerary_posts where id = new.post_id;

  -- Post already gone (race with a delete), or liking your own post —
  -- neither should award XP.
  if _author_id is null or _author_id = new.user_id then
    return new;
  end if;

  insert into public.xp_events (user_id, amount, reason, source_type, source_id)
  values (
    _author_id, 2, 'Someone liked your trip', 'post_liked',
    new.post_id::text || ':' || new.user_id::text
  )
  on conflict (user_id, source_type, source_id) do nothing;
  return new;
end;
$$;

drop trigger if exists post_likes_award_xp on public.post_likes;

create trigger post_likes_award_xp
  after insert on public.post_likes
  for each row execute function public.award_xp_on_post_liked();

-- Follower gained: recipient is the followee. follows.check
-- (follower_id <> followee_id) already rules out self-follow. source_id
-- encodes the (follower, followee) pair so unfollow/refollow by the same
-- follower only ever awards once, while a different follower still does.
create or replace function public.award_xp_on_follower_gained()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.xp_events (user_id, amount, reason, source_type, source_id)
  values (
    new.followee_id, 5, 'You gained a follower', 'follower_gained',
    new.follower_id::text || ':' || new.followee_id::text
  )
  on conflict (user_id, source_type, source_id) do nothing;
  return new;
end;
$$;

drop trigger if exists follows_award_xp on public.follows;

create trigger follows_award_xp
  after insert on public.follows
  for each row execute function public.award_xp_on_follower_gained();

-- Comment posted: recipient is the commenter (rewarding the act of
-- participating, not the post's author). source_id = the comment's own id
-- — always a fresh primary key, so there is no toggle to farm.
create or replace function public.award_xp_on_comment_posted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.xp_events (user_id, amount, reason, source_type, source_id)
  values (new.author_id, 3, 'Left a comment', 'comment_posted', new.id::text)
  on conflict (user_id, source_type, source_id) do nothing;
  return new;
end;
$$;

drop trigger if exists post_comments_award_xp on public.post_comments;

create trigger post_comments_award_xp
  after insert on public.post_comments
  for each row execute function public.award_xp_on_comment_posted();
