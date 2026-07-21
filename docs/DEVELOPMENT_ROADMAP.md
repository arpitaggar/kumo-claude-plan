# Kumo Development Roadmap

**Project:** Kumo — Collaborative Travel Super-App  
**Current Version:** 2.0 (as-built)  
**Previous Version:** 1.0 (original plan)  
**Target Launch:** Q3 2026

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
| Social layer | Feed with likes, comments, follows, gamification (XP/badges) | Read-only Discover feed (public itineraries) | Full social graph is a separate product surface; deferred |
| B2B portal | Multi-tenant schema, travel policies, admin dashboard | Not built | Requires pilot customer; premature to build without validated demand |
| Chat polish | Typing indicators, read receipts | Built (Stage 16) | Read receipts via SECURITY DEFINER RPC; typing indicators via Realtime Broadcast |
| New (not in v1.0) | — | Packing lists, trip notes, share sheet, offline banner, home search, profile stats | Surfaced as higher value during implementation |

---

## Stage Mapping: v1.0 → v2.0

```
v1.0 Stage 1 (MVP Core)            →  v2.0 Stage 1 (Foundation) ✅
                                       v2.0 Stage 7 (Offline Cache) ✅ (subset only)
v1.0 Stage 2 (Collaboration)       →  v2.0 Stage 2 (Collaboration) ✅ (simplified)
v1.0 Stage 3 (Agentic AI)          →  v2.0 Stage 3 (AI Generation) ✅ (simplified)
                                       v2.0 Stage 8 (AI Integration) ✅
v1.0 Stage 4 (Fintech + Ratings)   →  v2.0 Stage 4 (Expenses + Ratings) ✅ (no Stripe)
v1.0 Stage 5 (Social + B2B)        →  v2.0 Stage 6 (Discover + Notes) ✅ (subset only)

Not in v1.0                        →  v2.0 Stage 5 (Packing Lists) ✅
Not in v1.0                        →  v2.0 Stage 7 (Connectivity + Search) ✅ (partial)
Not in v1.0                        →  v2.0 Stage 9 (Polish + Release Prep) ⬜
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

## What Remains (Deferred / Not Implemented)

| Feature | Why Deferred |
|---------|-------------|
| Katha AI (live) | Needs Anthropic API key — Edge Function ready to deploy |
| Invite email (Resend branded) | Needs Resend account + domain — Supabase built-in fallback works today |
| GitHub Pages for legal docs | Enable in repo Settings → Pages → /docs; submit URL to app stores |
| WCAG 2.1 full accessibility audit | Partial (send button + dots done); full audit deferred |
| Widget + integration tests | Domain + model + legal widget tests done; full UI coverage deferred |
| Concierge AI mode (agents, streaming) | Requires backend agent infrastructure |
| Virtual Debit Card (Stripe Issuing) | Legal/compliance review required |
| Social feed (likes, comments, follows) | Separate product surface |
| Gamification (XP, achievements, badges) | Post-retention-baseline |
| B2B portal | Requires pilot customer |

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
└── Stage 16: Chat Polish, Animations & A11y ✅ Week 7
```

---

## Quality Gates

- `flutter analyze` passes with zero issues ✅
- No secrets committed to git (`.env` in `.gitignore`, API keys in Supabase secrets) ✅
- Supabase RLS enabled on all tables ✅
- Clean Architecture layer boundaries respected ✅
- GDPR right to erasure implemented (account deletion RPC + in-app flow) ✅
- Privacy Policy and Terms of Service pages in-app and as hosted HTML ✅
- Signup consent checkbox before account creation ✅
- 154 unit tests passing ✅

Outstanding:
- Run `stage14_delete_user_rpc.sql` migration in Supabase SQL editor
- Enable GitHub Pages → submit legal URLs to App Store Connect / Google Play Console
- Widget tests and integration tests not yet written
- No formal WCAG 2.1 accessibility audit
- Solo development; no PR review process

---

**End of Development Roadmap v2.0**
