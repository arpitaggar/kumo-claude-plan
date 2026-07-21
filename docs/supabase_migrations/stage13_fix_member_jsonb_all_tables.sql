-- =============================================================================
-- Stage 13 — Fix camelCase/snake_case JSONB key mismatch across all tables
-- Safe to re-run.
-- =============================================================================
-- The handle_new_user trigger writes members with camelCase keys (userId,
-- userName, joinedAt). The Flutter client writes snake_case keys (user_id,
-- user_name, joined_at). Policies that use jsonb @> with hard-coded 'userId'
-- only match trigger-written members; Flutter-direct members are blocked.
--
-- This migration replaces ALL remaining @> containment checks with
-- EXISTS + jsonb_array_elements so both key formats are accepted.
-- Tables fixed: ratings, expenses, messages.
-- (itineraries was already fixed in stage12.)
-- =============================================================================

-- ─── Helper macro (inline — Postgres has no macros, repeated per table) ──────

-- ─── ratings ─────────────────────────────────────────────────────────────────

drop policy if exists "Members can view ratings"   on public.ratings;
drop policy if exists "Members can add ratings"    on public.ratings;
drop policy if exists "Author or owner can delete rating" on public.ratings;

create policy "Members can view ratings" on public.ratings
  for select using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );

create policy "Members can add ratings" on public.ratings
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );

create policy "Author or owner can delete rating" on public.ratings
  for delete using (
    user_id = auth.uid()
    or exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id and i.owner_id = auth.uid()
    )
  );

-- ─── expenses ────────────────────────────────────────────────────────────────

drop policy if exists "Members can view expenses"  on public.expenses;
drop policy if exists "Members can add expenses"   on public.expenses;
drop policy if exists "Members can delete expenses" on public.expenses;

create policy "Members can view expenses" on public.expenses
  for select using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );

create policy "Members can add expenses" on public.expenses
  for insert with check (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );

create policy "Members can delete expenses" on public.expenses
  for delete using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where (m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text)
              and m->>'role' in ('owner', 'editor')
          )
        )
    )
  );

-- ─── messages ────────────────────────────────────────────────────────────────

drop policy if exists "messages_owner_all"     on public.messages;
drop policy if exists "messages_member_read"   on public.messages;
drop policy if exists "messages_member_insert" on public.messages;

create policy "messages_owner_all" on public.messages
  for all
  using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id and i.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id and i.owner_id = auth.uid()
    )
  );

create policy "messages_member_read" on public.messages
  for select using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and exists (
          select 1 from jsonb_array_elements(i.members) as m
          where m->>'user_id' = auth.uid()::text
             or m->>'userId'  = auth.uid()::text
        )
    )
  );

create policy "messages_member_insert" on public.messages
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );
