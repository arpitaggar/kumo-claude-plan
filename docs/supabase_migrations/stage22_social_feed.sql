-- =============================================================================
-- Stage 22 — Social feed: publish-as-snapshot, fork lineage, likes, follows
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. itinerary_posts
--    Publishing an itinerary snapshots it into an immutable row here instead
--    of flipping a visibility flag on the live itineraries row — editing your
--    itinerary after publishing must NOT change what's already public.
--    Author name/avatar are denormalised at publish time (not joined from
--    profiles at read time) so the feed never needs a join to render a card,
--    and a post still shows correctly if the author later changes their name.
--    `snapshot` holds the itinerary's items and trip_segments at publish time,
--    in the same JSON shapes ItineraryModel/TripSegmentModel already produce
--    — a fork is built entirely from this column, so it survives the source
--    itinerary or its segments being edited or deleted later.
-- -----------------------------------------------------------------------------

create table if not exists public.itinerary_posts (
  id                  uuid        primary key default gen_random_uuid(),
  source_itinerary_id uuid        references public.itineraries(id) on delete set null,
  author_id           uuid        not null references auth.users(id) on delete cascade,
  author_name         text        not null,
  author_avatar_url   text,
  forked_from_post_id uuid        references public.itinerary_posts(id) on delete set null,
  title               text        not null,
  description         text,
  start_date          timestamptz not null,
  end_date            timestamptz not null,
  theme_key           text        not null default 'classic',
  currency_code       text        not null,
  snapshot            jsonb       not null,
  like_count          int         not null default 0,
  created_at          timestamptz not null default now()
);

create index if not exists itinerary_posts_created_at_idx
  on public.itinerary_posts (created_at desc);

create index if not exists itinerary_posts_author_id_idx
  on public.itinerary_posts (author_id, created_at desc);

alter table public.itinerary_posts enable row level security;

drop policy if exists "itinerary_posts_read_all"    on public.itinerary_posts;
drop policy if exists "itinerary_posts_author_insert" on public.itinerary_posts;

-- Posts are the public feed itself — readable by any authenticated user.
create policy "itinerary_posts_read_all" on public.itinerary_posts
  for select using (auth.role() = 'authenticated');

-- Immutable once written: insert-only, no update/delete policy for v1
-- (unpublishing/deleting a post is deferred). like_count is written only by
-- sync_post_like_count() below (SECURITY DEFINER), never by the client.
create policy "itinerary_posts_author_insert" on public.itinerary_posts
  for insert with check (author_id = auth.uid());

alter publication supabase_realtime add table public.itinerary_posts;

-- -----------------------------------------------------------------------------
-- 2. origin_post_id on itineraries
--    Set when an itinerary is created by forking a post. Read back when that
--    itinerary is later published, so the new post's forked_from_post_id
--    chains to the original without the client having to track lineage itself.
-- -----------------------------------------------------------------------------

alter table public.itineraries
  add column if not exists origin_post_id uuid references public.itinerary_posts(id) on delete set null;

-- -----------------------------------------------------------------------------
-- 3. post_likes
--    Event log, not a mutable flag — itinerary_posts.like_count is a
--    denormalised counter kept in sync by the trigger below, mirroring how
--    expense_summary / read_receipts are already derived from event rows
--    elsewhere in this schema.
-- -----------------------------------------------------------------------------

create table if not exists public.post_likes (
  post_id    uuid        not null references public.itinerary_posts(id) on delete cascade,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.post_likes enable row level security;

drop policy if exists "post_likes_read_all"    on public.post_likes;
drop policy if exists "post_likes_own_insert"  on public.post_likes;
drop policy if exists "post_likes_own_delete"  on public.post_likes;

create policy "post_likes_read_all" on public.post_likes
  for select using (auth.role() = 'authenticated');

create policy "post_likes_own_insert" on public.post_likes
  for insert with check (user_id = auth.uid());

create policy "post_likes_own_delete" on public.post_likes
  for delete using (user_id = auth.uid());

create or replace function public.sync_post_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (tg_op = 'INSERT') then
    update public.itinerary_posts
      set like_count = like_count + 1
      where id = new.post_id;
    return new;
  elsif (tg_op = 'DELETE') then
    update public.itinerary_posts
      set like_count = greatest(like_count - 1, 0)
      where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists post_likes_sync_count on public.post_likes;

create trigger post_likes_sync_count
  after insert or delete on public.post_likes
  for each row execute function public.sync_post_like_count();

alter publication supabase_realtime add table public.post_likes;

-- -----------------------------------------------------------------------------
-- 4. follows
-- -----------------------------------------------------------------------------

create table if not exists public.follows (
  follower_id uuid        not null references auth.users(id) on delete cascade,
  followee_id uuid        not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create index if not exists follows_followee_id_idx on public.follows (followee_id);

alter table public.follows enable row level security;

drop policy if exists "follows_read_all"     on public.follows;
drop policy if exists "follows_own_insert"   on public.follows;
drop policy if exists "follows_own_delete"   on public.follows;

create policy "follows_read_all" on public.follows
  for select using (auth.role() = 'authenticated');

create policy "follows_own_insert" on public.follows
  for insert with check (follower_id = auth.uid());

create policy "follows_own_delete" on public.follows
  for delete using (follower_id = auth.uid());

alter publication supabase_realtime add table public.follows;
