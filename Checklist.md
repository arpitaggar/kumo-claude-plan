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
