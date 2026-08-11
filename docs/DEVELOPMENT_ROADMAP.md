# Kumo Development Roadmap

**Project:** Kumo — Collaborative Travel Super-App  
**Current Version:** 2.1 (as-built)  
**Previous Version:** 1.0 (original plan) → 2.0 (Stage 1–19, through masked trip email)  
**Target Launch:** Q3 2026

> **2026-08-11 refresh:** This doc was last substantively written before the social feed grew into a real social product surface and before any B2B/org work existed (Stage 19 and earlier only). Stages 20–23 below cover everything shipped since — see `Checklist.md` (repo root) for the full, continuously-updated day-by-day log this doc summarizes; that file is the actual source of truth going forward, not this one.

---

## What Changed: v1.0 → v2.0

The original 5-stage plan was restructured during implementation. Stages were broken into smaller, shippable chunks. Several planned features were descoped or simplified; others not in the original plan were added based on what made the product more useful immediately.

### Summary of Divergences

| Area | v1.0 Plan | v2.0 Actual | Reason |
|------|-----------|-------------|--------|
| Offline storage | Isar database (full offline-first) | SharedPreferences JSON cache | Isar adds codegen complexity with marginal benefit for this scope |
| Conflict resolution | Vector clocks + event sourcing | Last-write-wins on JSONB | Vector clocks are production-scale infrastructure; deferred |
| AI tier | Skeletal mode + Concierge mode (CrewAI agents, streaming) | Single-call generation (Claude Haiku) | Agentic AI requires backend infrastructure not yet in place |
| AI security | Supabase Edge Function (key server-side) | Direct client call (key in .env) | Edge function scaffolding deferred; acceptable for dev/beta |
| Fintech | Expense split + Virtual Debit Card (Stripe Issuing) + Stripe Connect | Expense split only | Stripe Issuing requires legal/compliance review; deferred |
| Social layer | Feed with likes, comments, follows, gamification (XP/badges) | Real social feed shipped (Stage 20): publish-as-snapshot with fork lineage, likes, follows, comments, delete/unpublish, in-app + push notifications, cursor pagination, server-side search. Only gamification (XP/badges) remains deferred. | Superseded the original read-only Discover-tab plan once built out; gamification is genuinely a separate, later concern |
| B2B portal | Multi-tenant schema, travel policies, admin dashboard | Minimal real foundation shipped (Stage 21): organizations, org-tagged trips, expense-approval workflow, cost-center fields, self-serve join codes (QR + manual + deep link), per-department approval thresholds and feature-flag overrides, and a client-side "Work Mode" toggle (Stage 22) separating personal/work context. No admin dashboard or travel-policy engine. | Built the minimum real B2B substrate a pilot customer would actually need, rather than the full portal speculatively; admin-side workflows are explicitly left to a future admin portal or an external system (e.g. SAP), not this app |
| Chat polish | Typing indicators, read receipts | Built (Stage 16) | Read receipts via SECURITY DEFINER RPC; typing indicators via Realtime Broadcast |
| New (not in v1.0) | — | Packing lists, trip notes, share sheet, offline banner, home search, profile stats, destination-based trip themes, trip route segments with routed geometry, weather chips, premium feature flags, masked trip email, an 11th ("Onyx & Gold") enforced theme for Work Mode | Surfaced as higher value during implementation |

---

## Stage Mapping: v1.0 → v2.0

```
v1.0 Stage 1 (MVP Core)            →  v2.0 Stage 1 (Foundation) ✅
                                       v2.0 Stage 7 (Offline Cache) ✅ (subset only)
v1.0 Stage 2 (Collaboration)       →  v2.0 Stage 2 (Collaboration) ✅ (simplified)
v1.0 Stage 3 (Agentic AI)          →  v2.0 Stage 3 (AI Generation) ✅ (simplified)
                                       v2.0 Stage 8 (AI Integration) ✅
v1.0 Stage 4 (Fintech + Ratings)   →  v2.0 Stage 4 (Expenses + Ratings) ✅ (no Stripe)
v1.0 Stage 5 (Social + B2B)        →  v2.0 Stage 6 (Discover + Notes) ✅ (subset only, superseded)
                                       v2.0 Stage 20 (Real Social Feed) ✅
                                       v2.0 Stage 21 (Orgs / minimal B2B) ✅ (subset only)
                                       v2.0 Stage 23 (Gamification) ✅

Not in v1.0                        →  v2.0 Stage 5 (Packing Lists) ✅
Not in v1.0                        →  v2.0 Stage 7 (Connectivity + Search) ✅ (partial)
Not in v1.0                        →  v2.0 Stage 9 (Polish + Release Prep) ⬜
Not in v1.0                        →  v2.0 Stage 22 (Work Mode toggle) ✅
```

---

## v2.0 Stages (As Built)

---

### Stage 1 — Foundation ✅
**Shipped:** Auth (sign up, login, password reset, session persistence), itinerary CRUD, clean architecture (Domain → Data → Presentation), Riverpod state management, GoRouter navigation, Supabase integration, Material 3 theme, error/failure hierarchy.

**vs. v1.0:** Matches the v1.0 Stage 1 scope except Isar offline DB (replaced by SharedPreferences in Stage 7) and optimistic UI (deferred).

---

### Stage 2 — Real-Time Collaboration ✅
**Shipped:** Trip members (JSONB array), role management (owner/editor/viewer), invite by email (Supabase lookup), role change + member removal, real-time chat (Supabase Realtime), inbox with unread badge, privacy settings.

**vs. v1.0:** No vector clocks, event sourcing, or conflict resolution. Concurrent edits are last-write-wins on the `itineraries` JSONB `members` column. No typing indicators or read receipts.

---

### Stage 3 — AI Itinerary Generation ✅
**Shipped:** `AiGenerationRequest` entity with destination, dates, travel style, interests. Single Claude Haiku call via Anthropic API. JSON parsing with fallback regex extraction. Bottom sheet UI with form → loading → preview → accept/regenerate flow. Integrated into Create Trip page.

**vs. v1.0:** No Concierge mode, no CrewAI/LangChain agents, no streaming responses, no Supabase Edge Function (API key is client-side in `.env`), no generation history or caching, no iterative refinement ("add more nightlife"). This covers roughly the Skeletal Mode from v1.0.

---

### Stage 4 — Expense Splitting + Ratings ✅
**Shipped:** Expense logging (title, amount, category, payer, per-member splits), budget tracker with progress bar, settlement calculation (greedy debt minimization), real-time expense stream. Star ratings (1–5) with comments on activities/destinations, rating summary view.

**vs. v1.0:** No virtual debit card, no Stripe Issuing or Stripe Connect, no payment settling, no CSV export, no PCI-DSS compliance work. The "Splitwise Clone" scope shipped; the fintech layer did not.

---

### Stage 5 — Packing Lists ✅
**Not in v1.0.** Added: per-trip packing list with Supabase Realtime sync, checkbox toggle (shared state — all members see changes live), progress bar, category field, per-item creator tracking, delete with swipe. Integrated as a tab in the trip detail page.

---

### Stage 6 — Discover Feed, Trip Sharing & Notes ✅
**Shipped:** `is_public` toggle on itinerary (owner-only), Discover tab showing public trips with search, clone itinerary (new trip with fresh owner/members). Native share sheet via `share_plus`. Shared trip notes (full-screen debounced editor, real-time sync, read-only for viewers).

**vs. v1.0:** This is a lightweight version of v1.0 Stage 5's social/discovery concept — no likes, comments, follows, or social graph. The Discover feed is read-only browsing + clone, not a full social feed.

---

### Stage 7 — Connectivity, Offline Cache & Home Search ✅
**Shipped:** `connectivity_plus` network monitoring, `isOnlineProvider` Riverpod stream, `OfflineBanner` shown in shell when offline, `ItineraryLocalDataSource` (SharedPreferences JSON cache), `fetchItineraries` falls back to cache on failure. Home page search bar (client-side filter on title/description). Avatar tap fixed to `/profile`.

**vs. v1.0:** This delivers the offline-fallback part of v1.0 Stage 1 but with SharedPreferences instead of Isar. No auto-sync of offline mutations (reads only).

---

### Stage 8 — AI Integration into Existing Trips + Profile Stats ✅
**Not in v1.0 as a separate stage.** Added "AI" button (owner/editor only) in the trip detail Schedule header — opens the generation sheet and appends items to the existing trip. Profile stats card showing total trips, upcoming trips, days traveled derived from `itineraryListProvider`.

---

### Stage 9 — Polish, Onboarding & Release Prep ✅
**Shipped:** First-run onboarding (3-screen `PageView` walkthrough, animated dot indicator, skip + CTA buttons), `OnboardingNotifier` with tri-state `bool?` to avoid redirect races, GoRouter wired to gate authenticated first-time users on `/onboarding`. CSV expense export in the Expenses tab via `share_plus`. Domain-layer unit test suite: 25 tests across `CreateItineraryUseCase`, `FetchItinerariesUseCase`, `UpdateItineraryUseCase`, `DeleteItineraryUseCase`.

---

### Stage 10 — Destination-Based Trip Themes ✅
**Shipped:** 8 static theme presets (`classic`, `sakura`, `tropical`, `alpine`, `desert`, `nordic`, `mediterranean`, `rainforest`), each with a primary colour, header gradient, card accent gradient, and background tint. `TripTheme.resolve(title)` keyword-matches ~100 region keywords to auto-suggest a theme as the user types. `TripThemePicker` horizontal swatch row in `CreateItineraryPage` with animated selection state; manual pick disables auto-suggest. Theme applied to `ItineraryCard` accent bar and `ItineraryDetailPage` header + background. `theme_key` column added to `itineraries` table with CHECK constraint.

---

### Stage 11 — Invite System Fixes + Email ✅
**Shipped:** Fixed two RLS bugs blocking the pending-invitation invite flow. (1) `pending_invitations_member` policy now allows editors (not just owners) to send invites. (2) Policy checks both `user_id` (snake_case, Flutter) and `userId` (camelCase, Postgres trigger) to handle both key formats. `supabase/functions/invite-email` Edge Function sends invite email via Resend if `RESEND_API_KEY` is configured, or falls back to Supabase's built-in `auth.admin.inviteUserByEmail`.

---

### Stage 12 — Multi-User Collaboration Bug Fixes ✅
**Shipped:** Three bugs fixed stemming from a JSONB key format inconsistency between the Flutter client (snake_case) and the `handle_new_user` Postgres trigger (camelCase). (1) `GroupMemberModel.fromJson` now reads both `user_id`/`userId`, `user_name`/`userName`, `joined_at`/`joinedAt`. (2) `fetchItineraries` owner_id filter removed — RLS controls visibility. (3) `itineraries_member_select`, `itineraries_member_update`, `ratings`, `expenses`, and `messages` RLS policies updated to use `EXISTS + jsonb_array_elements` accepting both key formats.

SQL migrations: `stage12_fix_member_visibility.sql`, `stage13_fix_member_jsonb_all_tables.sql`.

---

### Stage 13 — Katha AI: Security Hardening & Branding ✅
**Shipped:** Anthropic API key moved from `.env` (client binary) to a Supabase Edge Function secret. `supabase/functions/generate-itinerary` accepts the request, verifies the caller's JWT, calls Anthropic server-side, and returns the parsed item list. `dio` package removed. AI assistant named **Katha** (Hindi: *कथा*, "story") across all UI strings. AI entry points show "Katha AI coming soon ✨" placeholder until the Edge Function is deployed and API key configured.

**Deploy when ready:**
```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase functions deploy generate-itinerary
```

---

### Stage 14 — App Icon & Launch Screen ✅
**Shipped:** Royal blue app icon (`kumo_app_icon_royal_blue.svg`) converted to 1024×1024 PNG via `librsvg`. `flutter_launcher_icons` generated all Android mipmap densities + adaptive icon (background `#1E3A8A`) and all iOS AppIcon sizes (alpha stripped for App Store). iOS launch screen updated: storyboard background → royal blue, `LaunchImage.imageset` → white stacked logo at @1x/@2x/@3x. Android `launch_background.xml` updated: royal blue fill + centred `launch_logo.png`.

---

### Stage 15 — Privacy, GDPR & Legal Compliance ✅
**Shipped:** Full GDPR compliance layer.

**Account deletion (GDPR Art. 17):** `delete_user()` Supabase RPC (`SECURITY DEFINER`) cascades to all app data. `DeleteAccountUseCase` → `AuthRemoteDataSource.deleteAccount()` → `AuthRepositoryImpl` → `AuthNotifier.deleteAccount()`. Danger zone in Privacy Settings with confirmation dialog.

**In-app legal pages:** `PrivacyPolicyPage` (13 sections, GDPR-compliant) and `TermsPage` (16 sections, England & Wales governing law) at `/legal/privacy-policy` and `/legal/terms`. Both routes accessible without authentication.

**Signup consent:** Checkbox with tappable inline links to both pages via `TapGestureRecognizer`. "Create Account" button disabled until ticked.

**Privacy Settings:** Legal section with links + danger zone Delete Account tile.

**Hosted HTML:** `docs/legal/privacy-policy.html` and `docs/legal/terms.html` for GitHub Pages — submit these URLs to App Store Connect and Google Play Console.

**SQL migration:** `docs/supabase_migrations/stage14_delete_user_rpc.sql` — run in Supabase SQL editor before enabling account deletion.

---

### Stage 16 — Chat Polish, Animations & Accessibility ✅
**Shipped:**

**Read receipts:** `read_by text[]` column on `messages` table. `mark_messages_read(p_itinerary_id)` RPC (SECURITY DEFINER) appends caller's UID without a broad UPDATE policy. `_ReadTick` widget in outgoing bubbles: double-tick (full opacity) when read, single-tick (55% opacity) when delivered. Called on chat open and on each new message arrival.

**Hero animations:** `Hero(tag: 'trip-header-${id}')` on the 4px gradient accent bar in `ItineraryCard` and on the full `SliverAppBar` background in `ItineraryDetailPage`. Flutter interpolates size and position automatically on push/pop.

**Slide transitions:** `_slidePage<T>` helper in `router.dart` using `CustomTransitionPage` + `SlideTransition` (right→left, `easeInOutCubic`, 280ms/240ms). Applied to all full-screen push routes; shell tabs remain `NoTransitionPage`.

**Accessibility:** `_DotsAnimation` wrapped with `ExcludeSemantics` (decorative). `_SendButton` wrapped with `Semantics(label: 'Send message', button: true, enabled: !isSending)`.

**Test coverage:** 13 widget tests (`legal_pages_test.dart`) + 11 unit tests (`message_model_test.dart`) = 178 tests total.

**SQL migration:** `docs/supabase_migrations/stage15_read_receipts.sql` — run before read receipts go live.

---

### Stage 17 — Chat Attachments, Extended Profile, Dark Themes & Push Notifications ✅ (Android) / 🔧 (iOS)

**Note on numbering:** this roadmap's stage count and the per-feature "Stage N" labels used in `CLAUDE.md` / `docs/supabase_migrations/` drifted apart after this document was first written — `CLAUDE.md`'s Stage 16–19 (Extended Profile, Expense Improvements, Avatar Storage, Chat Upgrade) all landed in the gap between this doc's Stage 16 and this entry. See `CLAUDE.md` for the authoritative, currently-maintained breakdown of what shipped in each; this entry only covers what's relevant to "what remains."

**Shipped:** Extended user profile (username/bio/location/preferences, privacy controls), expense split-mode/multi-currency/settlement improvements, avatar upload to Supabase Storage, message photo attachments, per-user read-receipt detail, three new themes including the app's first dark theme (Synthwave Tokyo), and the Firebase project setup (app renamed to `com.cygnus.travelKumo`, `google-services.json` / `GoogleService-Info.plist` added).

**Push notification delivery — Android done, iOS scaffolded but not live:**
- Android: FCM token registration, an Edge Function (`supabase/functions/send-message-push`) that sends a data-only push on every chat message, and a background isolate handler that displays it via `flutter_local_notifications` even when the app is killed. Code-complete; needs `supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY=...` + `supabase functions deploy send-message-push` before it's live.
- iOS: entitlements + Xcode project wiring done (validated with a real `flutter build ios --no-codesign`), and the Edge Function sends a proper APNs alert payload for iOS tokens. Gated behind `kIosPushReady` (`lib/core/notifications/push_config.dart`) until an APNs key is uploaded in Firebase and the Push Notifications capability is enabled in Xcode.

---

### Stage 18 — Trip Route Segments, Pluggable Map & Premium Feature Flags ✅

**Note on numbering:** same drift called out in Stage 17 — this entry's "Stage 18" is this roadmap doc's own sequence. `CLAUDE.md` labels the equivalent work "Stage 20" in its own (separately-drifted) numbering; see `CLAUDE.md` → *Trip Route Segments, Pluggable Map & Premium Feature Flags* for the authoritative technical breakdown.

**Shipped:** A trip's transport can now be planned as an ordered sequence of legs (e.g. Flight Munich→Bangkok → Flight Bangkok→Chiang Mai → Motorcycle Chiang Mai→Pai → ... → Flight Bangkok→Munich), each with a transport mode, shown on a new "Route" tab as a map with per-mode icons plus a segment list. Tapping a segment (card or map marker) opens an actions sheet to continue the trip from that stop, edit, or delete it. Map rendering is pluggable: `flutter_map`/OpenStreetMap ships as the free default; `google_maps_flutter` is a second implementation behind the same interface, switchable from a new Settings picker.

Also added a general-purpose, DB-backed premium feature-flag system (`feature_flags` table) and an append-only premium-status audit log (`profile_status` table, replacing what would otherwise have been a flat `is_premium` column) — modeled after the existing `username_history`/`profile_change_log` pattern so a look at any user's premium history always has a reason attached. Ships a 14-day signup trial (length configurable via a new `app_config` key/value table) with everything currently free (`google_maps` flag unset).

**vs. v1.0:** Not in the original plan — added based on user request during development.

**SQL migration:** `docs/supabase_migrations/stage21_trip_segments.sql` — run in Supabase SQL editor before deploying this build.

**Known gaps carried into "What Remains" below:** Google Maps needs a real API key dropped into the gitignored native config to actually render tiles; org/sub-org inheritance for premium defaults is explicitly deferred (no organisation entity exists yet to hang it off).

**Follow-up (same stage):** added unit/widget test coverage for the new usecases, model, and widgets (usecase/model tests + `SegmentCard`/segment-actions-sheet/`RouteMapView`-empty-state/`AddEditTripSegmentPage`-add-mode widget tests), and made Katha AI's (still-dormant, see Stage 3) generation pipeline segment-aware — the `generate-itinerary` Edge Function and Flutter parsing now also produce transport legs for multi-stop destinations, geocoded and inserted via the same Route tab infrastructure. Nothing calls this yet since Katha AI's entry points are still placeholders pending Edge Function deployment.

**Follow-up (Route tab bug fixes + features):** Deleting a segment no longer renumbers/re-upserts the rest of the route (was a self-inflicted "shuffle" bug) — the Route tab now sorts chronologically by departure/arrival time instead of the manual `order_index`, so delete is a single `DELETE` with no side effects on siblings. Added a per-segment visibility toggle (`SegmentCard`, `is_visible` column, `stage25_trip_segment_visibility.sql`) to hide a leg from the map without deleting it, an origin/destination swap button on the add/edit segment page, and `stage26_trip_segments_replica_identity.sql` fixing routed geometry reverting to a straight line after any partial-column update (Postgres drops unchanged TOASTed `jsonb` columns from Realtime's payload under the default `REPLICA IDENTITY`).

---

### Stage 19 — Masked Trip Email (Inbound Forwarding) 🔧

**Shipped:** Every itinerary now gets an auto-generated masked email alias (`trip-xxxxxxxxxx@<domain>`, `trip_email_aliases` table populated by an on-insert trigger) shown on the trip Overview tab with a copy button. The alias is forward-only — no inbox — so it can be handed to airlines, hotels, or event organisers instead of a personal address: a new `inbound-trip-email` Edge Function receives mail sent to it (from whichever inbound-email provider is wired up), looks up the trip, and re-sends the message to every member's real address via Resend, `reply_to` set back to the original sender so replies go to the vendor, not into the void. Rate-limited to 20 forwards/trip/hour; only forward metadata (sender, subject, timestamp) is ever logged (`trip_email_forward_log`) — never the message body.

**vs. v1.0:** Not in the original plan — added based on user request during development.

**SQL migration:** `docs/supabase_migrations/stage27_trip_email_alias.sql` — run in Supabase SQL editor before deploying this build (safe to run before the provider setup below is done; the alias just won't receive real mail yet).

**Known gaps carried into "What Remains" below:** live mail delivery needs a domain you control DNS for, an inbound-email provider (Cloudflare Email Routing, Postmark, or Mailgun — Resend does outbound only, not inbound) pointed at that domain and POSTing to the Edge Function, and the `INBOUND_WEBHOOK_SECRET` secret (plus the existing `RESEND_API_KEY`/`RESEND_FROM` from Stage 11). None of that is code — see `supabase/functions/inbound-trip-email/index.ts`'s header comment for the full checklist.

---

### Stage 20 — Real Social Feed: Publish, Likes, Follows, Comments, Notifications ✅

**Note on numbering:** this stage's own migrations are numbered stage33–38 in `docs/supabase_migrations/`; the roadmap-stage number here is this doc's own sequence, continuing from Stage 19. Full day-by-day detail lives in `Checklist.md`, not duplicated here.

**Shipped:** The Stage 6 "read-only Discover feed" grew into a real social product surface. Publishing an itinerary now snapshots it into `itinerary_posts` (with fork lineage back to the original if forked from someone else's post), likes and follows with their own tables and rate limits, author-only delete/unpublish, a full comment thread per post (bottom-sheet UI, not a new route), and an in-app + push notification system (`lib/features/notifications/`) covering likes/follows/new-posts/comments — with its own unread badge and mark-read-on-open flow. Explore search is now real server-side search (`pg_trgm`) instead of a 50-post client-side filter, and both feed tabs use cursor pagination with a bounded in-memory window (`PostFeedNotifier`, capped at 200 posts) instead of unbounded "Load more" accumulation.

**vs. v1.0:** This is the v1.0 Stage 5 social-graph concept, actually built — likes, comments, follows are all here now. Only gamification (XP/achievements/badges) remains deferred, and there's still no algorithmic ranking (chronological only).

**SQL migrations:** `stage33_social_feed_scale.sql` through `stage38_post_comments.sql`, run in order — all ✅ live on the database.

---

### Stage 21 — Organizations & Minimal B2B Foundation ✅ (subset of the original B2B vision)

**Note on numbering:** migrations stage28–32 (RLS hardening) and stage39 (department overrides) — again, see `Checklist.md` for the day-by-day breakdown; this entry is the high-level summary.

**Shipped:** A real, minimal organization layer: `organizations`/`org_members` with roles, trips taggable to an org (`itineraries.org_id`, owner-only, only to an org you belong to — RLS-enforced, not just UI-restricted), an expense-approval workflow with admin review, configurable cost-tracking fields per org (including a `select`-type department field and a `generated` cost-center-code field), and a self-serve join-code system (QR display/scan, manual entry, and a `kumo://join?code=...` deep link) so a new member can get into an org without an admin doing it by hand. Stage 39 added per-department auto-approval thresholds (an expense strictly under the threshold auto-approves on submit) and per-department feature-flag overrides (a premium-gating exception, e.g. "everyone in Sales gets Google Maps regardless of trial status").

**vs. v1.0:** A real but intentionally minimal slice of the original "multi-tenant schema, travel policies, admin dashboard" vision — no admin dashboard, no travel-policy engine, no multi-org-per-user support (the product currently assumes at most one org per user). Deliberately scoped this way rather than building further speculatively without a pilot customer; see Stage 22 below for how a user actually experiences being in an org day-to-day.

**SQL migrations:** `stage28_work_mode_orgs.sql` through `stage32_security_hardening_2.sql`, `stage35_org_join_codes.sql`, `stage39_department_overrides.sql` — **all ✅ live on the database (stage39 confirmed 2026-08-11).**

**Security note:** a mid-build review of this stage found and fixed 4 real RLS issues before anything shipped broadly (an `org_members` policy self-recursion bug, an unauthenticated trip-email-alias IDOR, a cross-tenant expense-injection path, and an over-broad org-admin `SELECT` grant that leaked full trip rows instead of just row-existence — see `docs/SECURITY_AUDIT.md` SEC-026 through SEC-029). The over-broad grant was fully removed, not narrowed — org admins today have no direct table-level read access into trips they don't own or aren't a member of.

---

### Stage 22 — Work Mode / Private Mode Toggle ✅

**Shipped:** A global mode switch, requested directly rather than audit-driven, for the subset of users who both belong to an org (Stage 21) and travel personally — a consultant being the motivating case. Work Mode forces a distinct dark "Onyx & Gold" theme and a "Kumo — for {Org}" banner so the mode is never ambiguous, filters Home/Trips to the current context (only the signed-in user's own trips at the current org while in Work Mode — deliberately never an admin-oversight view of teammates' trips), and auto-tags new trips to the org instead of a manual picker. Invisible to the majority of users who belong to zero orgs.

**vs. v1.0:** Not in the original plan. A UX layer on top of Stage 21's org substrate, not new backend capability — purely client-side (theme/filter/banner), no new tables or RLS.

**Follow-up audit pass (same day):** found and fixed one real bug (org management was accidentally gated on "Work Mode currently on" instead of "user has an org," locking org-admin tasks like generating a join code behind first switching into Work Mode) and corrected a stale code comment that cited an RLS grant already removed in Stage 21's security pass. See `Checklist.md`'s 2026-08-11 audit-round entry for the full writeup.

---

### Stage 23 — Gamification: XP, Levels, and Badges ✅

**Shipped:** Closes out the last piece of the original v1.0 social-layer brief ("Feed with likes, comments, follows, gamification (XP/badges)" — the rest shipped in Stage 20). XP is awarded entirely by Postgres triggers on tables that already exist (`itineraries`, `itinerary_posts`, `post_likes`, `follows`, `post_comments`) — the exact same shape `public.notifications` already uses — so no existing mutation code path changes at all; the whole feature is new, read-only Flutter code (`lib/features/gamification/`) reading an append-only `xp_events` ledger. A `GamificationCard` on the Profile page shows level + XP progress + badge count and pushes a new `/achievements` page (full 8-badge grid, locked vs. earned, plus recent XP activity). 8 badges, purely derived from the ledger client-side (no separate `badges` table) — e.g. "First Steps" (plan a trip), "Globetrotter" (complete 5 trips), "Century Club" (100 XP).

**vs. v1.0:** Not in the original plan as a separate stage, but directly closes a gap the original brief named explicitly. Anti-cheat closes two abuse vectors by construction: a unique dedup index (not a rate-limit trigger) keyed so a trip's status can't be flipped back and forth to farm the completion award, and so unlike/relike or unfollow/refollow by the same actor can't re-earn a like/follow award.

**Deliberate scope trims:** expenses excluded as an XP source (no rate limit anywhere on that table today — trivially farmable); no push notification or persisted `notifications` row for a badge unlock (in-app celebration dialog only).

**SQL migration:** `docs/supabase_migrations/stage40_gamification.sql`, patched by `stage41_gamification_rate_limits.sql` (SEC-032 — rate-limits the trip creation/completion XP triggers) — **✅ both run against the live database (2026-08-11).**

---

## What Remains (Deferred / Not Implemented)

| Feature | Why Deferred |
|---------|-------------|
| Katha AI (live) | Needs Anthropic API key — Edge Function ready to deploy |
| Push notifications (live) | Android code-complete, needs Edge Function deployed + Firebase service-account secret set; iOS scaffolded but gated on an APNs key + Xcode capability, see Stage 17 |
| Invite email (Resend branded) | Needs Resend account + domain — Supabase built-in fallback works today |
| GitHub Pages for legal docs | Enable in repo Settings → Pages → /docs; submit URL to app stores |
| WCAG 2.1 full accessibility audit | Partial (send button + dots done); full audit deferred |
| Widget + integration tests | Domain/model/legal/organization/social/work-mode/gamification coverage now substantial (919 tests as of 2026-08-11); still no end-to-end integration test suite, and neither the join-code deep link, Work Mode's retheme/banner/filtering, nor gamification's card/dialog/grid has ever been smoke-tested on a real device or simulator (none available in this dev environment) |
| Concierge AI mode (agents, streaming) | Requires backend agent infrastructure |
| Virtual Debit Card (Stripe Issuing) | Legal/compliance review required |
| Full B2B admin portal (dashboard, travel-policy engine) | Stage 21 shipped the minimal real substrate (orgs, expense approval, cost fields, join codes, department overrides); the admin-facing surface on top of it is explicitly left to a future admin portal or an external system (e.g. SAP), not this app |
| Multi-org-per-user support | Product currently assumes at most one org per user (Stage 21/22) — a user in more than one silently falls back to the first rather than picking; revisit if that assumption ever breaks in practice |
| Google Maps route rendering (live) | Code-complete behind the map-provider abstraction (Stage 18); needs a real Google Cloud Maps API key dropped into the gitignored `google_maps_api.xml` (Android) / `Secrets.xcconfig` (iOS) — currently builds with a placeholder key so tiles won't render |
| Masked trip email (live) | Code-complete (Stage 19); needs a domain + inbound-email provider (Cloudflare Email Routing / Postmark / Mailgun) wired to `inbound-trip-email`, plus the `INBOUND_WEBHOOK_SECRET` secret set — see that stage's entry above |
| SEC-014 (Firebase key rotation) | The one open finding in `docs/SECURITY_AUDIT.md` that can't be closed by a code change — a manual Firebase console action |
| Background job/queue infrastructure | `docs/SCALABILITY_AUDIT.md` SCALE-002 — the prerequisite for the *proper* long-term version of the like-counter and for scaling push fan-out past trip-sized groups; not justified until real fan-out traffic shows up |
| Architecture cleanup backlog | `docs/SOLID_AUDIT.md`'s 12-item ranked list (a few providers typed to concrete classes instead of interfaces, `SocialRepository` bundles 3 concerns, some enum-driven rendering duplicated across 3-4 files) — incremental, non-blocking, tracked there rather than here |

---

## Timeline Overview (v2.0 Actual)

```
Jun–Jul 2026
├── Stage 1:  Foundation                     ✅ Weeks 1–2
├── Stage 2:  Collaboration                  ✅ Week 3
├── Stage 3:  AI Generation                  ✅ Week 3
├── Stage 4:  Expenses + Ratings             ✅ Week 4
├── Stage 5:  Packing Lists                  ✅ Week 4
├── Stage 6:  Discover + Notes + Sharing     ✅ Week 5
├── Stage 7:  Connectivity + Offline         ✅ Week 5
├── Stage 8:  AI Integration + Profile       ✅ Week 5
├── Stage 9:  Polish + Onboarding            ✅ Week 6
├── Stage 10: Destination Themes             ✅ Week 6
├── Stage 11: Invite Fixes + Email           ✅ Week 6
├── Stage 12: Collaboration Bug Fixes        ✅ Week 6
├── Stage 13: Katha AI Security + Branding   ✅ Week 6
├── Stage 14: App Icon & Launch Screen       ✅ Week 7
├── Stage 15: Privacy, GDPR & Legal          ✅ Week 7
├── Stage 16: Chat Polish, Animations & A11y ✅ Week 7
├── Stage 17: Profile/Expense/Chat/Push      ✅ Android / 🔧 iOS   Jul 2026
├── Stage 18: Route Segments + Premium Flags ✅                   Aug 2026
├── Stage 19: Masked Trip Email              🔧                   Aug 2026
├── Stage 20: Real Social Feed               ✅                   Aug 2026
├── Stage 21: Organizations / Minimal B2B    ✅                   Aug 2026
├── Stage 22: Work Mode Toggle               ✅                   Aug 2026
└── Stage 23: Gamification (XP/Badges)       ✅                   Aug 2026
```

---

## Quality Gates

- `flutter analyze` — zero warnings/errors; ~260 info-level style nits tolerated (same bar applied consistently across the codebase — see `docs/SOLID_AUDIT.md`/`Checklist.md` for what those are) ✅
- No secrets committed to git (`.env` in `.gitignore`, API keys in Supabase secrets) ✅
- Supabase RLS enabled on all tables, and independently security-reviewed twice (2026-08-05, 2026-08-09) — see `docs/SECURITY_AUDIT.md` ✅
- Every SQL migration, through `stage41_gamification_rate_limits.sql`, is confirmed live against the production database (2026-08-11) ✅
- Clean Architecture layer boundaries respected — audited (`docs/SOLID_AUDIT.md`), no domain-layer framework leaks anywhere including the newest features ✅
- GDPR right to erasure implemented (account deletion RPC + in-app flow) ✅
- Privacy Policy and Terms of Service pages in-app and as hosted HTML ✅
- Signup consent checkbox before account creation ✅
- **919 unit/widget tests passing** (up from 227) ✅
- Scalability audit complete — every finding fixed-and-live, explicitly decided, or documented as not-yet-justified at this app's actual scale (`docs/SCALABILITY_AUDIT.md`) ✅

Outstanding:
- SEC-014: rotate the Firebase key via the Firebase console (the one open security finding that isn't a code change)
- Deploy/redeploy the Edge Functions with their secrets set: `generate-itinerary` (Katha AI, `ANTHROPIC_API_KEY`), `send-message-push` (push notifications, `FIREBASE_SERVICE_ACCOUNT_KEY`), and `invite-email` — all three also still need the `ALLOWED_ORIGIN` secret from SEC-002; ship a Flutter build via `--dart-define-from-file=env.local.json` to go with it
- Drop a real Google Maps API key into the gitignored native config files to make that map provider actually render (Stage 18)
- Wire up an inbound-email provider + `INBOUND_WEBHOOK_SECRET`, then deploy `inbound-trip-email`, to make masked trip email actually receive mail (Stage 19)
- Enable GitHub Pages → submit legal URLs to App Store Connect / Google Play Console
- No end-to-end integration test suite; the join-code deep link, Work Mode (Stage 22), and gamification's card/dialog/grid (Stage 23) have never been smoke-tested on a real device or simulator — none available in this dev environment
- No formal WCAG 2.1 accessibility audit
- Solo development; no PR review process

---

**End of Development Roadmap v2.1** — see `Checklist.md` for the continuously-updated day-by-day log this document summarizes.
