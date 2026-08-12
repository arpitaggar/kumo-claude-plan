-- =============================================================================
-- Stage 43 — Make avatars/chat-attachments Storage buckets private.
--
-- Found during the 2026-08-12 legal/privacy audit and confirmed by product:
-- both buckets were public=true, meaning anyone with the object URL (not
-- authenticated, not a trip member, not even a Kumo user) could fetch the
-- file directly, regardless of what the surrounding app-level access
-- controls said. chat-attachments in particular can hold photographed
-- travel documents (boarding passes, passport pages) — a general-purpose
-- file upload with no content restriction.
--
-- This flips both buckets to public=false and replaces their blanket
-- "anyone can SELECT" policy with real per-object authorization:
--
--   avatars: mirrors profiles_select's own visibility logic exactly
--   (auth.uid() = id OR profile_visibility = 'public' OR is_searchable =
--   true — see stage23_security_hardening.sql's SEC-004 fix) so avatar
--   access never grants more than the profile row itself already does. A
--   user's own uploaded avatar is always visible to them; a private,
--   non-searchable profile's avatar is now actually private, closing the
--   exact gap the audit flagged. This is also what "toggle the
--   searchability of their profile" in Privacy Settings now controls for
--   avatars — no separate avatar-visibility toggle needed.
--
--   chat-attachments: readable only by a member (or the owner) of the trip
--   whose chat the attachment was posted in, via the same itinerary
--   membership check used throughout this schema (dual-key `user_id`/
--   `userId` — see SEC-018's note on why both casings must be checked).
--
-- getPublicUrl() (used client-side to build the stored avatar_url /
-- message_attachments.public_url values) is pure string construction, not a
-- network call — it keeps working identically after this change and is
-- still used purely to encode {bucket}/{path}. The app now exchanges that
-- URL for a real signed URL before rendering (see
-- lib/core/network/signed_storage_url.dart) — this migration only needs to
-- land before/alongside that client change ships, not before it.
--
-- Safe to re-run: uses DROP POLICY IF EXISTS / CREATE POLICY throughout.
-- Run in Supabase SQL editor before deploying the corresponding app build.
-- =============================================================================

-- ── 1. Flip both buckets to private ──────────────────────────────────────────

update storage.buckets set public = false where id in ('avatars', 'chat-attachments');

-- ── 2. avatars: replace unconditional public read ────────────────────────────

drop policy if exists "avatars_public_read" on storage.objects;

create policy "avatars_visibility_read" on storage.objects
  for select
  using (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.profiles p
        where p.id::text = (storage.foldername(name))[1]
          and (p.profile_visibility = 'public' or p.is_searchable = true)
      )
    )
  );

-- avatars_owner_insert / _update / _delete (stage18) are unaffected — they
-- already scope writes to the caller's own {uid}/ prefix regardless of the
-- bucket's public flag.

-- ── 3. chat-attachments: replace unconditional public read ──────────────────

drop policy if exists "chat_attachments_public_read" on storage.objects;

create policy "chat_attachments_member_read" on storage.objects
  for select
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1
      from public.message_attachments ma
      join public.messages m on m.id = ma.message_id
      join public.itineraries i on i.id = m.itinerary_id
      where ma.storage_path = storage.objects.name
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as mem
            where mem->>'user_id' = auth.uid()::text
               or mem->>'userId' = auth.uid()::text
          )
        )
    )
  );

-- chat_attachments_owner_insert / _delete (stage19) are unaffected.
