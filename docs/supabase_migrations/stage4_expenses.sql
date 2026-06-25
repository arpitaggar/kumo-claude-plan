-- Stage 4: Expense Splitting
-- Run this in the Supabase SQL editor after stage2b_invite_and_privacy.sql

-- ─── Clean up any artifacts from previous failed runs ─────────────────────────
-- Safe to run even on a fresh database; CASCADE drops dependent policies/indexes.

drop table if exists public.expenses cascade;

-- ─── Table ────────────────────────────────────────────────────────────────────

create table public.expenses (
  id            uuid primary key default gen_random_uuid(),
  itinerary_id  uuid not null references public.itineraries(id) on delete cascade,
  title         text not null,
  amount        numeric(12, 2) not null check (amount > 0),
  currency_code text not null default 'USD',
  category      text not null default 'other',
  payer_id      uuid not null references auth.users(id),
  payer_name    text not null,
  -- Each element: { "userId": "...", "userName": "...", "shareAmount": 12.50 }
  splits        jsonb not null default '[]'::jsonb,
  created_at    timestamptz not null default now()
);

-- ─── Indexes ──────────────────────────────────────────────────────────────────

create index expenses_itinerary_id_idx
  on public.expenses (itinerary_id, created_at desc);

-- ─── RLS ──────────────────────────────────────────────────────────────────────

alter table public.expenses enable row level security;

-- Use IN (subquery) so that `itinerary_id` sits in the outer USING expression
-- and unambiguously refers to the expenses row being evaluated.  Avoids the
-- correlated-subquery column-resolution issue seen with EXISTS in some Supabase
-- versions.

-- SELECT: trip owner or any member can view expenses
create policy "Members can view expenses"
  on public.expenses for select
  using (
    itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
         or members @> ('[{"userId":"' || auth.uid()::text || '"}]')::jsonb
    )
  );

-- INSERT: trip owner or any member can add an expense (must be the declared payer)
create policy "Members can add expenses"
  on public.expenses for insert
  with check (
    payer_id = auth.uid()
    and itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
         or members @> ('[{"userId":"' || auth.uid()::text || '"}]')::jsonb
    )
  );

-- DELETE: only the payer or the trip owner can delete an expense
create policy "Payer or owner can delete expense"
  on public.expenses for delete
  using (
    payer_id = auth.uid()
    or itinerary_id in (
      select id from public.itineraries
      where owner_id = auth.uid()
    )
  );

-- ─── Realtime ─────────────────────────────────────────────────────────────────

alter publication supabase_realtime add table public.expenses;
