-- Stage 4: Kumo Ratings
-- Run this in the Supabase SQL editor after stage4_expenses.sql

-- ─── Table ────────────────────────────────────────────────────────────────────

create table if not exists public.ratings (
  id            uuid primary key default gen_random_uuid(),
  itinerary_id  uuid not null references public.itineraries(id) on delete cascade,
  -- Optional link to a specific ItineraryItem (stored as UUID string)
  item_id       text,
  target_name   text not null,
  stars         smallint not null check (stars between 1 and 5),
  comment       text,
  user_id       uuid not null references auth.users(id),
  user_name     text not null,
  created_at    timestamptz not null default now()
);

-- ─── Indexes ──────────────────────────────────────────────────────────────────

create index if not exists ratings_itinerary_id_idx
  on public.ratings (itinerary_id, created_at desc);

create index if not exists ratings_user_id_idx
  on public.ratings (user_id);

-- ─── Aggregate view: average stars per target ─────────────────────────────────

create or replace view public.rating_summaries as
  select
    itinerary_id,
    target_name,
    item_id,
    count(*)::int                              as review_count,
    round(avg(stars)::numeric, 1)              as avg_stars
  from public.ratings
  group by itinerary_id, target_name, item_id;

-- ─── RLS ──────────────────────────────────────────────────────────────────────

alter table public.ratings enable row level security;

-- SELECT: any member of the itinerary can read ratings
create policy "Members can view ratings"
  on public.ratings for select
  using (public.is_itinerary_member(itinerary_id));

-- INSERT: any member can add a rating, must be their own user_id
create policy "Members can add ratings"
  on public.ratings for insert
  with check (
    auth.uid() = user_id
    and public.is_itinerary_member(itinerary_id)
  );

-- DELETE: only the author or the itinerary owner can delete a rating
create policy "Author or owner can delete rating"
  on public.ratings for delete
  using (
    auth.uid() = user_id
    or public.is_itinerary_owner(itinerary_id)
  );

-- ─── Realtime ─────────────────────────────────────────────────────────────────

alter publication supabase_realtime add table public.ratings;
