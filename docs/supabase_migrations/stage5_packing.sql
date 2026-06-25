-- Stage 5: Packing Lists
-- Run this in the Supabase SQL editor after stage4_ratings.sql.

drop table if exists public.packing_items cascade;

-- ─── Table ────────────────────────────────────────────────────────────────────

create table public.packing_items (
  id              uuid        primary key default gen_random_uuid(),
  itinerary_id    uuid        not null references public.itineraries(id) on delete cascade,
  title           text        not null,
  is_checked      boolean     not null default false,
  added_by_id     uuid        not null references auth.users(id),
  added_by_name   text        not null,
  category        text,
  created_at      timestamptz not null default now()
);

-- ─── RLS ──────────────────────────────────────────────────────────────────────

alter table public.packing_items enable row level security;

create policy "trip members can view packing items"
  on public.packing_items for select
  using (
    itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
         or members @> ('[{"userId":"' || auth.uid()::text || '"}]')::jsonb
    )
  );

create policy "trip members can insert packing items"
  on public.packing_items for insert
  with check (
    added_by_id = auth.uid()
    and itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
         or members @> ('[{"userId":"' || auth.uid()::text || '"}]')::jsonb
    )
  );

create policy "trip members can update packing items"
  on public.packing_items for update
  using (
    itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
         or members @> ('[{"userId":"' || auth.uid()::text || '"}]')::jsonb
    )
  );

create policy "item creator or trip owner can delete packing items"
  on public.packing_items for delete
  using (
    added_by_id = auth.uid()
    or itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
    )
  );

-- ─── Realtime ─────────────────────────────────────────────────────────────────

alter publication supabase_realtime add table public.packing_items;
