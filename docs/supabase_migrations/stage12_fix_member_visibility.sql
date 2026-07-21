-- =============================================================================
-- Stage 12 — Fix member visibility for shared trips
-- Safe to re-run.
-- =============================================================================
-- Problem 1: itineraries_member_select and itineraries_member_update used
--   jsonb @> containment with the camelCase key 'userId'. Members added
--   directly via the Flutter client are stored with snake_case 'user_id',
--   so those members could never see or edit the trip.
--
-- Problem 2: the Flutter fetchItineraries query filtered .eq('owner_id', uid)
--   which excluded all shared trips regardless of RLS — fixed in Dart.
--
-- Fix: replace @> containment with EXISTS + jsonb_array_elements so we can
--   check both key formats (snake_case from Flutter, camelCase from trigger).
-- =============================================================================

drop policy if exists "itineraries_member_select" on public.itineraries;
drop policy if exists "itineraries_member_update" on public.itineraries;

-- Any member (any role) can read the trip.
create policy "itineraries_member_select" on public.itineraries
  for select using (
    owner_id = auth.uid()
    or exists (
      select 1
      from jsonb_array_elements(members) as m
      where m->>'user_id' = auth.uid()::text   -- Flutter client (snake_case)
         or m->>'userId'  = auth.uid()::text   -- trigger (camelCase)
    )
  );

-- Members with editor role can update the trip.
create policy "itineraries_member_update" on public.itineraries
  for update
  using (
    owner_id = auth.uid()
    or exists (
      select 1
      from jsonb_array_elements(members) as m
      where (m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text)
        and m->>'role' = 'editor'
    )
  )
  with check (
    owner_id = auth.uid()
    or exists (
      select 1
      from jsonb_array_elements(members) as m
      where (m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text)
        and m->>'role' = 'editor'
    )
  );
