-- ============================================================
-- Stage 6 — Discover Feed & Notes
-- ============================================================
-- Run this in the Supabase SQL editor after stage5_packing.sql.
-- Adds is_public flag and notes column to the itineraries table,
-- then updates RLS to allow public trips to be read by anyone.
-- ============================================================

-- ── Schema changes ────────────────────────────────────────────────────────────

alter table public.itineraries
  add column if not exists is_public boolean not null default false,
  add column if not exists notes     text;

-- ── Index for Discover feed queries ──────────────────────────────────────────

create index if not exists itineraries_is_public_created_at_idx
  on public.itineraries (created_at desc)
  where is_public = true;

-- ── RLS — update select policy to allow public trips ─────────────────────────
-- Drop and recreate the existing select policy so public trips are readable
-- by any authenticated user (required for the Discover feed).

drop policy if exists "users can view own and member itineraries" on public.itineraries;

create policy "users can view own, member, and public itineraries"
on public.itineraries for select
using (
  owner_id = auth.uid()
  or members @> ('[{"userId":"' || auth.uid()::text || '"}]')::jsonb
  or is_public = true
);

-- ── Realtime (already enabled in stage1; nothing to add) ─────────────────────
-- Public trips will appear in realtime subscriptions for all users
-- once is_public = true. No additional publication needed.
