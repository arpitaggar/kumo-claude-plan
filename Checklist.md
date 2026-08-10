# Kumo — Brief vs. Actual Checklist

_Compiled 2026-08-09 from `docs/DEVELOPMENT_ROADMAP.md`, migration history, and a fresh architecture/security/dev-style audit._

## Done (from the v1.0 brief)

- [x] Foundation: auth, itinerary CRUD, Clean Architecture, Riverpod, GoRouter, Material 3
- [x] Collaboration: trip members/roles, invites, real-time chat, typing indicators, read receipts (simplified — last-write-wins JSONB, no vector clocks/event sourcing)
- [x] AI itinerary generation — single-call Claude Haiku, server-side via Edge Function (simplified from "Concierge" agentic mode)
- [x] Expense splitting + ratings (no Stripe Issuing/Connect)
- [x] Social/discovery layer — now a *real* social feed (publish-as-snapshot, fork lineage, likes, follows) superseding the original lightweight Discover tab
- [x] B2B — minimal real foundation shipped (orgs, expense approval workflow, cost-center fields) vs. the originally-envisioned full multi-tenant portal

## Remaining from the initial brief (still not built)

- [ ] Concierge AI mode — agentic/streaming generation
- [ ] Virtual debit card (Stripe Issuing) + Stripe Connect settlement
- [ ] Full B2B portal — travel policies, admin dashboard, multi-tenant beyond the current minimal org layer
- [ ] Isar offline-first storage + vector-clock conflict resolution — permanently descoped in favor of SharedPreferences cache + last-write-wins

## Added beyond the initial brief

- [x] Packing lists, trip notes, share sheet, offline banner, home search, profile stats
- [x] Destination-based trip themes (8 presets + auto-suggest) + 4 more visual themes incl. first dark theme
- [x] Trip route segments with pluggable map (flutter_map/OSM default, Google Maps alternate)
- [x] Real routed road/walking geometry for segments (OSRM + Google Directions) — committed `5e4adf0`; stale-geometry-on-edit gap found and fixed (see below)
- [x] Weather forecast chips per trip leg
- [x] Premium feature-flag system + 14-day trial
- [x] Masked, forward-only trip email alias with inbound forwarding
- [x] Work mode: org-scoped trips, expense approval workflow, cost-tracking fields
- [x] macOS build re-enabled for local dev/testing — committed `5e4adf0`

## Code-complete but not live (deployment gaps)

- [ ] Katha AI generation — needs `ANTHROPIC_API_KEY` secret + Edge Function deploy
- [ ] Push notifications — Android needs Firebase secret + deploy; iOS gated on APNs key + Xcode capability
- [ ] Google Maps tiles — needs a real API key (placeholder only)
- [ ] Masked email inbound delivery — needs a domain + inbound-email provider + webhook secret
- [ ] GitHub Pages for legal docs — not enabled

## Process/quality gaps surfaced by this audit

- [x] Fix the auth-repo catch-swallow bug in `lib/features/auth/data/repositories/auth_repository_impl.dart` (uncommitted `LocalStorageException` fallback can throw uncaught) — extracted into a `_userAfterCacheFailure()` helper with its own try/catch
- [x] Run `dart format .` (user ran it — 206/338 files reformatted) and install the `dart format`/`flutter analyze` pre-commit hook CLAUDE.md claims exists — added `scripts/hooks/pre-commit` + `scripts/install-git-hooks.sh` (tracked source, since git doesn't sync `.git/hooks/`) and installed it locally
- [x] Update `docs/SECURITY_AUDIT.md`, `docs/ARCHITECTURE.md`, `docs/SOLID_AUDIT.md`, and `lib/core/maps/CLAUDE.md` — all updated with 2026-08-09 findings/addenda (see below)
- [x] Fix unclosed `Sink` in `test/features/chat/presentation/providers/chat_provider_test.dart` — false positive (every caller closes it), suppressed with a targeted `// ignore: close_sinks` + comment explaining why
- [x] Fix raw exception text shown on-screen by `StartupErrorApp` in release builds — gated behind `kReleaseMode` (SEC-030)
- [x] Fix non-constant-time webhook-secret comparison in `supabase/functions/inbound-trip-email/index.ts` — added a `timingSafeEqual` helper (SEC-031)
- [x] Document the 3 work-mode RLS security-review findings (commit `ac53cf3`) in `docs/SECURITY_AUDIT.md` as SEC-026 through SEC-029, plus SEC-030/031 above

**Verification after fixes:** `flutter analyze` — 118 issues, all info-level, zero warnings/errors. `flutter test` — 471/471 passing. `dart format --set-exit-if-changed .` — clean (only `macos/build/` artifacts, not source, show drift).

## Route-geometry completeness pass (2026-08-09, after the above)

Verified the OSRM/Google Directions feature end-to-end (migration → service → provider dispatch → fetch trigger on add/edit/backfill → map rendering) rather than assuming the committed code was fully wired up. It was, with one real gap:

- [x] **Fixed:** editing a segment's origin/destination/mode left the *previous* routed geometry cached (`TripSegment.copyWith`'s `??` pattern can't null a field, and `updateSegment` writes the stale value straight back) — the map would show a road path from the old pin locations, permanently if the refetch ever failed. Added `TripSegmentRepository.clearRouteGeometry` (narrow patch, same pattern as `updateRouteGeometry`/`setSegmentVisibility`) and call it from `FetchTripSegmentRouteGeometry` before every refetch when the incoming segment already has cached geometry. 4 new tests in `fetch_trip_segment_route_geometry_test.dart`.
- **Open item, not fixed (flagging, not deciding for you):** `OsrmRoutingService` calls OSRM's public demo server (`router.project-osrm.org`), which OSRM's own project documents as evaluation-only — no SLA, rate-limited. Every failure already falls back to the existing straight/curved line (no user-facing error), so this isn't broken, but it's not a production-grade dependency either. Worth a decision before relying on it at real traffic: self-host OSRM, or accept the graceful-degradation behavior as-is for now.

**Re-verified:** `flutter analyze` — 118 issues, still all info-level. `flutter test` — 474/474 passing (+3 net after the 4 new tests). Not yet committed.

## Missing unit test pass (2026-08-09, after the above)

Audited actual test coverage (by grepping which classes are exercised inside `test/`, not just filename matching — the filename heuristic had false positives, e.g. the 4 social read usecases are covered by a combined `fetch_social_reads_usecase_test.dart`). Found and closed real gaps:

- [x] **`AuthRepositoryImpl`** — zero repository-level coverage despite being hand-edited twice this session. New `test/features/auth/data/repositories/auth_repository_impl_test.dart`, 28 tests covering every method, including a regression test for the earlier catch-swallow fix.
- [x] **`TripSegmentRepositoryImpl`** — zero coverage despite the new `clearRouteGeometry` logic above. New `test/features/itinerary/data/repositories/trip_segment_repository_impl_test.dart`, 17 tests covering every method.
- [x] **15 domain usecases with no test at all**: `SendMessageUseCase`, `FetchMyOrganizationsUseCase`, `FetchPendingExpenseApprovalsUseCase`, `FetchOrgMembersUseCase`, `FetchOrgCostFieldsUseCase`, `DeleteRatingUseCase`, `LogoutUseCase`, `FetchTripCostFieldValuesUseCase`, `SetTripCostFieldValuesUseCase`, `FetchItineraryUseCase`, `GenerateItineraryUseCase`, `DeleteExpenseUseCase`, `DeletePackingItemUseCase`, `TogglePackingItemUseCase`, `AddPackingItemUseCase` — one test file each (packing's three combined into `packing_write_usecases_test.dart`, matching the delegator-usecase pattern already established elsewhere in this codebase).

**Significant bug found while writing the `TripSegmentRepositoryImpl` stream test, not something the audit or the route-geometry pass had caught:**

- [x] **`Stream.handleError`'s callback return value is silently discarded — every `watch*` stream repository in the app was dropping realtime errors instead of surfacing them.** All 6 stream-based repositories (`ChatRepositoryImpl`, `PackingRepositoryImpl`, `ExpenseRepositoryImpl`, `ItineraryRepositoryImpl`, `TripSegmentRepositoryImpl`, `RatingRepositoryImpl`) built their `Either`-wrapped stream the same way: `.map(Right.new).handleError((e) => Left(...))`. `Stream.handleError`'s handler is `void Function(Object error)` — a returned `Left(...)` value is simply discarded, not injected into the stream (confirmed with an isolated repro, not just inference). Net effect: a Supabase Realtime connection error on any watched itinerary/chat/expenses/packing-list/trip-segments/ratings stream silently stopped updating instead of ever reaching the `AsyncError` state the UI is built to show (every consuming provider does `.fold((f) => throw Exception(f.message), ...)`, which only fires if a `Left` ever actually arrives). Fixed in all 6 files by switching to `StreamTransformer.fromHandlers`, whose `handleError(error, stackTrace, sink)` can actually call `sink.add(Left(...))`. Added/extended regression tests for all 6 (2 tests each, or folded into the two repos' full test files above) proving the error now reaches subscribers.

**Final verification:** `flutter analyze --no-fatal-infos` — 140 issues (up from 118; all new info-level style nits in the new test files, zero warnings/errors, exit 0. `flutter test` — **561/561 passing** (+87 from the 474 baseline above). `dart format lib/ test/` — clean. Not yet committed.

## Scalability audit + easy-fix remediation (2026-08-09)

Full audit written up separately at `docs/SCALABILITY_AUDIT.md` (12 findings, SCALE-001 through SCALE-012), answering "could this scale like Instagram?" Short answer: no, not without 3 subsystem rewrites, and that's expected at this app's actual stage. All items classified as "easy" (code/query/config, no new infrastructure) are now fixed:

- [x] **SCALE-001 — hot-row like counter.** Dropped the synchronous `like_count`-incrementing trigger; posts now count `post_likes` rows at read time via PostgREST's embedded-resource count (`post_likes(count)`), backed by a new `(user_id, created_at)` index.
- [x] **SCALE-003 — no rate limiting on likes/follows/posts.** Added `BEFORE INSERT` trigger-based limits (60 likes/min, 30 follows/min, 20 posts/hour per user) — the same counting pattern already used for AI-generation rate limits, necessarily a DB trigger here since these are direct client inserts with no Edge Function in front of them.
- [x] **SCALE-004 — unbounded follow-list query.** Capped `fetchFeed`'s `follows` lookup to the 1000 most-recently-followed accounts.
- [x] **SCALE-008 — Explore search only covered the 50 newest posts.** Real server-side search now, via `pg_trgm` + GIN indexes on `title`/`description` (kept substring-match UX rather than switching to word-based full-text search).
- [x] **SCALE-009 — no cursor pagination.** Added keyset pagination (`before: DateTime?`) through the full stack — datasource → repository → usecase → a new `PostFeedNotifier` (replacing the old flat `FutureProvider`s) — plus a working "Load more" button wired into both Discover tabs.
- [x] **SCALE-005 — no image resizing.** `resizedImageUrl()` rewrites Storage URLs to request width/quality-limited variants, wired into every avatar and the chat attachment thumbnail (not the full-screen viewer). **Gated behind `kImageResizingEnabled = false`** — deliberately not flipped on, since image transformation is a paid Supabase add-on and its unenabled-state behavior isn't something to assume without checking the live project first. Safe no-op until then.
- [x] **SCALE-011 — no read replicas/connection pooling.** Not a code change — documented as a Supabase dashboard toggle on the live project, outside what this session can do. See `docs/SCALABILITY_AUDIT.md`.

**New migration:** `docs/supabase_migrations/stage33_social_feed_scale.sql` — ✅ run against the live database (2026-08-09).

**Real bug found mid-implementation, not by the original audit:** `followingFeedProvider` watches `authNotifierProvider`; auth resolving through `AuthInitial` → `AuthLoading` → `AuthAuthenticated` on startup rebuilds-and-disposes the feed notifier more than once, and a stale in-flight fetch from an earlier instance could throw trying to set `state` after disposal. Fixed with `mounted` guards in `PostFeedNotifier` after every `await` — this was a real crash risk in the running app, caught by writing a correct test for the new pagination provider, not a test-harness artifact.

**Verification:** `flutter analyze --no-fatal-infos` — 144 issues, all info-level, zero warnings/errors. `flutter test` — **577/577 passing** (+16 from the 561 baseline: 7 `PostFeedNotifier` tests, 7 `resizedImageUrl`/`transformObjectUrl` tests, 2 model-fallback tests). `dart format lib/ test/` — clean. Not yet committed.

**Still open (deliberately not attempted — real infrastructure, not code fixes):** SCALE-002 (no background job/queue anywhere — the prerequisite for the *proper* long-term version of SCALE-001's counter and for ever scaling push fan-out past trip-sized groups), SCALE-006 (JSONB-array RLS scans — not urgent, group sizes are small), SCALE-007 (synchronous push fan-out — fine for this app's domain), SCALE-010 (Supabase Realtime's connection ceiling — a platform migration, not a bug), SCALE-012 (Nominatim/OSRM aren't production-scale — a provider decision, already flagged in the route-geometry pass above).

## Second scalability pass (2026-08-09, after all of the above)

Re-audited with the benefit of having just built the stage33 fixes and separately read the whole organization/work-mode schema in depth (during the coverage pass). Two findings, one fixed, one documented:

- [x] **SCALE-013 — `itinerary_posts` ended up with two overlapping rate-limit triggers.** The SCALE-003 fix added a 20/hour cap without noticing a 30-second-cooldown trigger already existed on the same table (stage23) — both index-backed and individually correct, but redundant (two scans per publish instead of one) and left two mechanisms for a future reader to reconcile. Folded into one trigger function. New migration `docs/supabase_migrations/stage34_consolidate_post_rate_limits.sql` — **not yet run against the live database.**
- [ ] **SCALE-014 — `PostFeedNotifier`'s "Load more" accumulates every loaded page in memory forever, documented not fixed.** A real but distant threshold (hundreds of "Load more" taps in one session) and a genuine product trade-off (windowing loses "scroll back up and it's still there"), not something to decide unilaterally — see `docs/SCALABILITY_AUDIT.md` for the standard fix pattern if it ever becomes real.

## Work mode: org join-code system (2026-08-10)

Self-serve onboarding for Work Mode — an org admin generates a code (shown as text + QR), and any authenticated user can redeem it to join that org, optionally scoped to a department (reusing the existing `org_cost_fields`/`org_cost_field_options` structure rather than a new entity). Full design/tradeoff writeup at `/Users/pitto/.claude/plans/synchronous-hopping-matsumoto.md`. Chosen over SSO — no enterprise customer in the pipeline demanding SAML/OIDC, and this schema (`org_members.cost_field_option_id`) is built so SSO could later become a second provisioning path into the same structure rather than a rewrite.

- [x] **New migration `docs/supabase_migrations/stage35_org_join_codes.sql`** — `org_join_codes` table (admin-only SELECT RLS, no direct insert/update/delete policy — all mutation goes through RPCs), `org_members.cost_field_option_id` column + cross-org guard trigger, and 3 `SECURITY DEFINER` RPCs: `generate_org_join_code` (admin-only, collision-checked random code), `revoke_org_join_code` (admin-only), `redeem_org_join_code` (any authenticated user; `FOR UPDATE` row lock for concurrency-safe limited-use redemption, successful-joins-per-hour cap, server-side-only org/user resolution — never trusts a client-supplied id). **✅ Run against the live database (2026-08-10).**
- [x] **Domain/data/presentation layers** — `OrgJoinCode` entity (`isRevoked`/`isExpired`/`isExhausted`/`isActive`), 4 new `OrganizationRepository` methods + usecases, `OrgJoinCodeModel`, datasource/repository impl wiring, `OrgJoinCodesPage` (admin: generate/list/revoke, code shown as copyable text + `qr_flutter` QR), `JoinOrganizationPage` (employee: `mobile_scanner` scan with a synchronous-before-first-`await` re-entrancy guard, or manual entry fallback). New entry points: 4th AppBar icon on `organization_members_page.dart`, "Join with code" action + empty-state link on `organizations_list_page.dart`. Router: `/organizations/join`, `/organizations/:id/join-codes`.
- [x] **New dependencies** `qr_flutter ^4.1.0`, `mobile_scanner ^7.4.0` — iOS `NSCameraUsageDescription` extended to cover scanning (was profile-picture-only), Android `CAMERA` permission + optional camera `<uses-feature>` added.
- [x] **Generalized `deleteCostFieldOption`'s error message** ("This value is in use and can't be deleted") since a join code can now also be the thing blocking deletion via the FK-restrict, not just a trip assignment.
- [x] **Tests** — `org_join_code_test.dart` (getter branching logic), `org_join_code_model_test.dart` (`fromJson`), 4 usecase test files, `organization_repository_impl_test.dart` extended with all 4 methods including one test per distinct RPC-raised message (invalid/revoked/expired/exhausted/already-a-member) confirming `redeemJoinCode` passes each through unchanged.
- **Explicit, acknowledged gap:** `redeem_org_join_code`'s `FOR UPDATE` concurrency correctness (the max-uses=1 double-redeem race) has no automated test — no pgTAP/ephemeral-PG-in-CI setup exists in this repo, same gap as every other RLS/trigger pass this session. Recommend one manual QA pass before this ships: two concurrent redemptions of the same `max_uses=1` code against a live/staging database, confirming exactly one succeeds.
- **Deliberately deferred:** per-department feature-flag overrides and per-department approval-routing/thresholds (this pass only gets people into the right org + department); a `kumo://join?code=...` deep link (no URL-scheme infra exists yet, and scanning inside the app already covers the stated use case); rate-limiting *failed* redeem guesses (not safely buildable in plain Postgres — `RAISE EXCEPTION` rolls back the attempt-log row along with everything else; relying on code entropy (~2^50 keyspace) + the successful-joins-per-hour cap instead).

**Verification:** `flutter analyze` — 208 issues repo-wide, all info-level, zero warnings/errors (only pre-existing-style infos, same tolerance already present elsewhere in this codebase). `flutter test` — **713/713 passing**, including 130 organization-feature tests (all new join-code coverage plus every pre-existing org test, run as one suite: `flutter test test/features/organization/`). `dart format lib/ test/` — clean. Not yet committed.

**Confirmed clean on closer inspection (not new fixes, just verified rather than assumed):** the stage31 RLS helper functions are correctly marked `stable`; the org/work-mode schema (stage28-30) is thoroughly indexed via implicit unique-constraint indexes on every lookup pattern actually used; `sync_post_like_count` was confirmed to be the *only* synchronous shared-counter hot-row pattern anywhere across all 34 migrations.

## Social feed gaps, part 1: unpublish/delete a post (2026-08-10)

First of three explicitly-deferred Stage 22 items (unpublish/delete, notifications, comments — see that stage's entry above), picked up at user request.

- [x] **New migration `docs/supabase_migrations/stage36_post_delete.sql`** — adds an author-only `delete` RLS policy to `itinerary_posts` (previously insert-only/immutable by design). No other schema change needed: `post_likes` already cascades on `post_id`, and both `itinerary_posts.forked_from_post_id` (self-FK) and `itineraries.origin_post_id` are already `on delete set null` (stage22), so deleting a post just silently drops "remixed from" lineage on any forks rather than blocking the delete or cascading through them. **Not yet run against the live database.**
- [x] **Domain/data** — `SocialRepository.deletePost(postId)` + `DeletePostUseCase`, datasource/repository impl wiring (a plain `.delete().eq('id', postId)`, RLS does the author check).
- [x] **UI** — `PostCard` gained an optional `onDelete` callback (null hides the affordance entirely — caller decides ownership, never the widget). Wired into `DiscoverPage`'s Explore/Following tabs (shown only when `post.authorId == currentUserId`, i.e. your own post can surface in the public feed too) and `PublicProfilePage`'s own-posts list (`isOwnProfile` gate), both behind the same delete-confirmation `AlertDialog` pattern already used for delete-account.
- **Deliberate scope decision, not re-litigated from stage22:** deleting a post does not touch `TravelItinerary.isPublic` (the "has this ever been published" badge) — that flag is a one-way historical marker by design, same as editing an itinerary never un-publishes it.
- **Tests** — `delete_post_usecase_test.dart`, a `deletePost` group in `social_repository_impl_test.dart`, and two new `PostCard` widget tests (affordance hidden when `onDelete` is null, fires when tapped).

**Verification:** `flutter analyze` — 208 issues, all info-level (same baseline as stage35). `flutter test` — 719/719 passing (+8 from the 711 baseline — note the running total in this doc undercounts slightly since `setUpAll`/`tearDownAll` pseudo-tests are counted by `flutter test`'s own tally but not by hand here). `dart format lib/ test/` — clean.

## Social feed gaps, part 2: like/follow/new-post notifications (2026-08-10)

Second of the three deferred Stage 22 items. Full design/rationale writeup at `lib/features/notifications/CLAUDE.md`.

- [x] **New migration `docs/supabase_migrations/stage37_social_notifications.sql`** — `public.notifications` table (no insert policy at all — every row written by a `SECURITY DEFINER` trigger, never a client insert), 3 triggers (`notify_on_post_like`, `notify_on_follow`, `notify_on_new_post` — the last fans out to followers, capped at 1000 same as `fetchFeed`), and a new `social_activity` notification-preferences category (same widen-constraint/reissue-seed-function/backfill pattern stage19 used for `chat_messages`). **Not yet run against the live database.**
- [x] **New feature `lib/features/notifications/`** — full Clean Architecture layers; one bounded realtime `.stream()` watch (50 rows, newest-first) backs the feed page, the unread badge, and the foreground local-notification watcher — a deliberate scope trim vs. full keyset pagination (documented, not hidden).
- [x] **UI** — bell icon + unread badge on `DiscoverPage`'s `AppBar` → `/notifications`; `NotificationsPage` marks everything read on open. Every notification type routes to the actor's `/u/:actorId` — no single-post detail route exists anywhere in this app to route to instead.
- [x] **Push delivery** — new Edge Function `supabase/functions/send-social-push`, mirroring `send-message-push`'s Android-data-only/iOS-alert split; invoked best-effort from `SocialRemoteDataSourceImpl` after like/follow/publish succeed, re-deriving recipients server-side rather than trusting the client. Extended the shared push infra (`push_message_handler.dart`, `NotificationService`) with a `kind: 'chat' | 'social'` discriminator so one background handler and one local-notification tap callback cover both push kinds — `send-message-push` picked up `kind: 'chat'` too, no behavior change.
- **Real bug caught while testing, not by design review:** `NotificationsPage` wrote directly to a `StateProvider` from `initState`/`dispose` — Riverpod forbids modifying a provider mid-build, and a widget's `initState`/`dispose` both count. Fixed by deferring both writes (`initState`'s via `addPostFrameCallback`, `dispose`'s via `Future.microtask` with a `StateController.mounted` guard, since the container can already be gone by the time a disposal-time microtask runs) — same pattern `ChatPage`'s `activeChatIdProvider` handling already uses, just not one this codebase had a test catching until now.
- **Tests** — new `test/features/notifications/` (entity, model, repository, both usecases, a widget test suite for `NotificationsPage`), plus 2 new `handleIosPushTap` cases in `test/core/notifications/push_message_handler_test.dart` for the social branch.

**Verification:** `flutter analyze` — 212 issues, all info-level (new ones are `prefer_const_literals`/`avoid_redundant_argument_values` nits in the new test files, same tolerance as the rest of this codebase). `flutter test` — **738/738 passing**. `dart format lib/ test/` — clean. Not yet committed.
