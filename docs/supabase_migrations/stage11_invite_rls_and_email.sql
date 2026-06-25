-- =============================================================================
-- Stage 11 — Fix invite RLS + add editor invite permission
-- Safe to re-run.
-- =============================================================================
-- Bug 1 (original): pending_invitations_owner only allowed the trip owner_id
--   to insert. Editors got a silent Postgres rejection.
-- Bug 2 (stage11 v1): the first version of this migration checked
--   m->>'userId' (camelCase) but GroupMemberModel.toJson() writes user_id
--   (snake_case). The JSONB lookup always returned NULL, blocking everyone.
-- Fix: drop both policies, create one that checks both key formats so it works
--   regardless of whether a member row was written by Flutter (snake_case) or
--   by the handle_new_user trigger (camelCase).
-- =============================================================================

drop policy if exists "pending_invitations_owner"  on public.pending_invitations;
drop policy if exists "pending_invitations_member" on public.pending_invitations;

create policy "pending_invitations_member" on public.pending_invitations
  for all
  using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          -- fast path: caller is the trip owner (indexed column)
          i.owner_id = auth.uid()
          or
          -- members with editor/owner role (handles both snake_case and camelCase keys)
          exists (
            select 1
            from jsonb_array_elements(i.members) as m
            where (
                m->>'user_id' = auth.uid()::text   -- Flutter client (snake_case)
                or m->>'userId' = auth.uid()::text  -- trigger (camelCase)
              )
              and m->>'role' in ('owner', 'editor')
          )
        )
    )
  )
  with check (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or
          exists (
            select 1
            from jsonb_array_elements(i.members) as m
            where (
                m->>'user_id' = auth.uid()::text
                or m->>'userId' = auth.uid()::text
              )
              and m->>'role' in ('owner', 'editor')
          )
        )
    )
  );
