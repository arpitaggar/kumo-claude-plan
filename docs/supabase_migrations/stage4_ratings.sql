-- Stage 4: Kumo Ratings
-- Run this in the Supabase SQL editor after stage4_expenses.sql

drop table if exists public.ratings cascade;

-- ─── Table ────────────────────────────────────────────────────────────────────

create table public.ratings (
  id            uuid primary key default gen_random_uuid(),
  itinerary_id  uuid not null references public.itineraries(id) on delete cascade,
  item_id       text,
  target_name   text not null,
  stars         smallint not null check (stars between 1 and 5),
  comment       text,
  user_id       uuid not null references auth.users(id),
  user_name     text not null,
  created_at    timestamptz not null default now()
);

-- ─── Indexes ──────────────────────────────────────────────────────────────────

create index ratings_itinerary_id_idx
  on public.ratings (itinerary_id, created_at desc);

create index ratings_user_id_idx
  on public.ratings (user_id);

-- ─── Aggregate view ───────────────────────────────────────────────────────────

create or replace view public.rating_summaries as
  select
    itinerary_id,
    target_name,
    item_id,
    count(*)::int                    as review_count,
    round(avg(stars)::numeric, 1)    as avg_stars
  from public.ratings
  group by itinerary_id, target_name, item_id;

-- ─── RLS ──────────────────────────────────────────────────────────────────────

alter table public.ratings enable row level security;

create policy "Members can view ratings"
  on public.ratings for select
  using (
    itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
         or members @> ('[{"userId":"' || auth.uid()::text || '"}]')::jsonb
    )
  );

create policy "Members can add ratings"
  on public.ratings for insert
  with check (
    user_id = auth.uid()
    and itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
         or members @> ('[{"userId":"' || auth.uid()::text || '"}]')::jsonb
    )
  );

create policy "Author or owner can delete rating"
  on public.ratings for delete
  using (
    user_id = auth.uid()
    or itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
    )
  );

-- ─── Realtime ─────────────────────────────────────────────────────────────────

alter publication supabase_realtime add table public.ratings;
