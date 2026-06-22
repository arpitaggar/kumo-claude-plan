-- Stage 4: Expense Splitting
-- Run this in the Supabase SQL editor after stage2b_invite_and_privacy.sql

-- ─── Table ────────────────────────────────────────────────────────────────────

create table if not exists public.expenses (
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

create index if not exists expenses_itinerary_id_idx
  on public.expenses (itinerary_id, created_at desc);

-- ─── RLS ──────────────────────────────────────────────────────────────────────

alter table public.expenses enable row level security;

-- Helper: is the calling user a member of the itinerary?
create or replace function public.is_itinerary_member(p_itinerary_id uuid)
returns boolean
language sql stable security definer
as $$
  select exists (
    select 1
    from public.itinerary_members
    where itinerary_id = p_itinerary_id
      and user_id = auth.uid()
  );
$$;

-- Helper: is the calling user the owner of the itinerary?
create or replace function public.is_itinerary_owner(p_itinerary_id uuid)
returns boolean
language sql stable security definer
as $$
  select exists (
    select 1
    from public.itineraries
    where id = p_itinerary_id
      and owner_id = auth.uid()
  );
$$;

-- SELECT: any member of the itinerary can read its expenses
create policy "Members can view expenses"
  on public.expenses for select
  using (public.is_itinerary_member(itinerary_id));

-- INSERT: any member can add an expense
create policy "Members can add expenses"
  on public.expenses for insert
  with check (
    auth.uid() = payer_id
    and public.is_itinerary_member(itinerary_id)
  );

-- DELETE: only the payer or the itinerary owner can delete an expense
create policy "Payer or owner can delete expense"
  on public.expenses for delete
  using (
    auth.uid() = payer_id
    or public.is_itinerary_owner(itinerary_id)
  );

-- ─── Realtime ─────────────────────────────────────────────────────────────────

-- Allow the expenses table to be streamed via Supabase Realtime.
alter publication supabase_realtime add table public.expenses;
