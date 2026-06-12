-- =============================================================================
-- Stage 1 — itineraries table
-- Run this FIRST, before stage2_profiles_and_messages.sql
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. itineraries table
--    Core entity. Members and items are embedded as JSONB arrays to keep the
--    schema simple for Stage 1. Stage 4+ will normalise these into join tables.
-- -----------------------------------------------------------------------------

create table if not exists public.itineraries (
  id              uuid        primary key default gen_random_uuid(),
  title           text        not null,
  description     text,
  owner_id        uuid        not null references auth.users(id) on delete cascade,
  start_date      timestamptz,
  end_date        timestamptz,
  total_budget    numeric(12,2) not null default 0,
  currency_code   text        not null default 'USD',
  members         jsonb       not null default '[]',
  items           jsonb       not null default '[]',
  expense_summary jsonb       not null default '{"total_spent":0,"spent_by_category":{},"member_balances":{}}',
  status          text        not null default 'draft'
                              check (status in ('draft','active','completed','archived')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- 2. updated_at trigger
--    Supabase Realtime uses updated_at to detect row changes.
-- -----------------------------------------------------------------------------

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_itinerary_updated on public.itineraries;
create trigger on_itinerary_updated
  before update on public.itineraries
  for each row execute procedure public.handle_updated_at();

-- -----------------------------------------------------------------------------
-- 3. Row Level Security
-- -----------------------------------------------------------------------------

alter table public.itineraries enable row level security;

-- Drop and recreate all policies so this script is idempotent.
drop policy if exists "itineraries_owner_all"      on public.itineraries;
drop policy if exists "itineraries_member_select"  on public.itineraries;
drop policy if exists "itineraries_member_update"  on public.itineraries;

-- Owner has full access.
-- IMPORTANT: `for all` needs BOTH `using` AND `with check` to cover INSERT.
-- Without `with check`, INSERTs are blocked even though the policy says `all`.
create policy "itineraries_owner_all" on public.itineraries
  for all
  using     (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Members listed in the JSONB array can view the itinerary.
-- The members array stores objects like: {"userId": "<uuid>", ...}
create policy "itineraries_member_select" on public.itineraries
  for select using (
    members @> jsonb_build_array(
      jsonb_build_object('userId', auth.uid()::text)
    )
  );

-- Members with editor role can update the itinerary (adding items, inviting).
create policy "itineraries_member_update" on public.itineraries
  for update
  using (
    members @> jsonb_build_array(
      jsonb_build_object('userId', auth.uid()::text, 'role', 'editor')
    )
  )
  with check (
    members @> jsonb_build_array(
      jsonb_build_object('userId', auth.uid()::text, 'role', 'editor')
    )
  );

-- -----------------------------------------------------------------------------
-- 4. Enable Realtime
-- -----------------------------------------------------------------------------

alter publication supabase_realtime add table public.itineraries;
