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
- [ ] Real routed road/walking geometry for segments (OSRM + Google Directions) — **uncommitted, in progress**
- [x] Weather forecast chips per trip leg
- [x] Premium feature-flag system + 14-day trial
- [x] Masked, forward-only trip email alias with inbound forwarding
- [x] Work mode: org-scoped trips, expense approval workflow, cost-tracking fields
- [ ] macOS build re-enabled for local dev/testing — **uncommitted**

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
