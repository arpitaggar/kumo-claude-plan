# lib/features/hitchhiker

Added 2026-08-12 — loads only when working under lib/features/hitchhiker/. Implements the Hitchhiker role: a non-account trip collaborator. See `docs/ARCHITECTURE.md`'s "Trip Roles: Captain / Crew / Hitchhiker, and the 18+ Age Gate" section for the regulatory rationale — **read that before changing anything here**, especially before adding any field that would give a Hitchhiker a persistent identity.

### Migration

`docs/supabase_migrations/stage45_hitchhikers.sql` — must be run in Supabase SQL editor before deploying the corresponding app build. Depends on `stage44_age_gate.sql`.

#### Schema

- `trip_hitchhikers` — `(id, itinerary_id, display_name, access_token, created_by, created_at, revoked_at)`. No `user_id`, no email, no phone, no DOB column — deliberately, not an oversight. RLS (`trip_hitchhikers_captain_all`) restricts all direct table access to the trip's Captain (`owner_id = auth.uid()`); a Hitchhiker never queries this table directly at all, only through the RPCs below.
- `itinerary_suggestions` — `(id, itinerary_id, title, description, suggested_by_hitchhiker_id, suggested_by_name, status, created_at)`. Hitchhiker-authored suggestions live here, not in `itineraries.items` — keeps every Hitchhiker write fully isolated from the core itinerary model, which stays owned/edited only by Captain/Crew through the existing, unrestricted path. The Captain reviews and (manually, today — no RPC for it yet) folds accepted suggestions into the real itinerary.
- `messages.hitchhiker_id` — nullable FK to `trip_hitchhikers`, alongside the now-nullable `messages.sender_id`. Exactly one of the two is set per row (`messages_sender_xor_hitchhiker` check constraint) — a message is always attributable to exactly one participant.

#### RPCs (all `SECURITY DEFINER`)

Captain-side (require a real session, `authenticated` only):
- `create_hitchhiker(p_itinerary_id, p_display_name)` — owner-only, returns `(id, access_token)`.
- `revoke_hitchhiker(p_hitchhiker_id)` — owner-only, sets `revoked_at`. Immediate: every subsequent token-RPC call checks `revoked_at is null`.

Hitchhiker-side (token only, granted to `anon` — **no session is ever expected**):
- `hitchhiker_get_trip_view(p_token)` — returns a deliberately minimal jsonb bundle (trip title/dates/status, messages, suggestions). Does **not** include `itineraries.members` (other travelers' identities) or `expense_summary` (financial data) — a Hitchhiker gets a read-only summary, never the raw row Captain/Crew get via normal RLS.
- `hitchhiker_send_message(p_token, p_content)` — inserts into `messages` with `hitchhiker_id` set, `sender_id` null.
- `hitchhiker_suggest_item(p_token, p_title, p_description)` — inserts into `itinerary_suggestions`.

No rate limiting on the token-authenticated RPCs yet — deliberately deferred (documented in the migration, same posture as `docs/SECURITY_AUDIT.md` SEC-021's like/follow deferral; tracked as its own finding, SEC-034). `access_token` is a random UUID shared only with the one person the Captain invited, and instantly revocable.

### Flutter layer

Standard Clean Architecture split, but with **two** repositories instead of one, because there are two different actors with fundamentally different authentication:

- **`HitchhikerRepository`** (`domain/repositories/hitchhiker_repository.dart`) — Captain-side, requires a session. `create`/`revoke`/`list`.
- **`HitchhikerAccessRepository`** (`domain/repositories/hitchhiker_access_repository.dart`) — token-side, no session ever. `getTripView`/`sendMessage`/`suggestItem`.
- **`presentation/providers/hitchhiker_provider.dart`** — wires both sides' datasources/repositories/usecases; `hitchhikersForTripProvider` (Captain's roster) and `hitchhikerTripViewProvider` (the token bundle) are the two `FutureProvider.family`s consuming code should watch.
- **`presentation/widgets/hitchhiker_tab.dart`** — the "Add Hitchhiker" tab wired into `lib/features/itinerary/presentation/pages/invite_member_page.dart` (a third tab alongside the existing Search/Email tabs, which both create Crew relationships). Generates a `kumo://hitchhiker?token=...` link (same custom-scheme convention as the existing `kumo://join?code=...` org-join deep link) shown as a QR code + copy/share sheet.
- **`presentation/pages/hitchhiker_screen.dart`** (route `/hitchhiker/:token`) — the Hitchhiker's own entry point. No login, no app shell, no bottom nav, no navigation to any other Kumo feature — deliberately isolated, since a Hitchhiker never becomes a general-purpose authenticated user of the app, just a guest on one trip. Two tabs: Chat and Suggest.
- **`lib/config/router.dart`** — `/hitchhiker/:token` is exempted from every auth/onboarding/age-gate redirect check (checked first, right after `/splash`) — it must be reachable regardless of whatever auth state the device happens to be in.

### `TripRole` (shared, not part of this feature module)

`lib/features/itinerary/domain/entities/trip_role.dart` — `enum TripRole { captain, crew, hitchhiker }`, `resolveTripRole(...)`, `isHitchhiker(TripRole)`. A classification layered on top of the existing storage model (owner_id / members / trip_hitchhikers), not a new column — lives in `itinerary/` rather than here since it's about labeling participants on a trip generally, not Hitchhiker-specific logic.

### Key design decisions

- **Token + RPC, not Supabase anonymous auth.** Considered and rejected — anonymous Supabase Auth accounts still create a real `auth.users` row, which would weaken "zero identity-system rows for anyone under 18" down to "anonymized rows." Every Hitchhiker action instead goes through an explicit `SECURITY DEFINER` RPC that takes the token as a plain parameter and validates it itself, mirroring the pattern this schema already uses for `delete_user()`/`mark_messages_read()`.
- **Captain-only, not Crew.** Only the trip owner can add/revoke Hitchhikers — matches the product decision literally; not extended to editor-role Crew members.
- **Suggestions, not direct itinerary edits.** A Hitchhiker's contributions land in a review queue (`itinerary_suggestions`), never as unreviewed direct writes to `itineraries.items`.
- **Structural exclusion from publishing/marketing/analytics/gamification** — not a checklist of "if hitchhiker, skip" checks scattered around the codebase. Every one of those systems keys off `auth.users`/`profiles`, and a Hitchhiker never has either, so there's nothing to forget to exclude.
