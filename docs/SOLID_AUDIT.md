# Kumo — SOLID Compliance Audit

- **Last Updated:** 2026-08-05 (see 2026-08-09 addendum below — findings 1-12 were not re-verified against the codebase as it stands today)
- **Scope:** full `lib/` tree (180 Dart files), read in full across five parallel passes — core/config/shared, domain layer (all features), data layer (all features), presentation layer group A (itinerary/social/chat/expense_split/ai_generation), presentation layer group B (auth/profile/settings/packing/ratings/onboarding/legal/shell/home/splash).
- **Overall verdict:** the architecture is fundamentally sound — Clean Architecture layering, `Either<Failure,T>`, one-usecase-per-operation, and Riverpod-as-DI are followed correctly in the large majority of the codebase. The violations found are consistent, learnable patterns repeated a handful of times each, not structural rot. Nothing here is an emergency; everything is fixable incrementally.

> **2026-08-09 addendum:** `lib/features/organization/` (work mode — orgs, expense approval, cost fields; ~50 files, stage28-30) and `lib/core/routing/` (OSRM/Google Directions route-geometry service) shipped after this audit was written and were **not** run through the same five-pass process — a fresh architecture spot-check (not a full SOLID pass) found no domain-layer framework leaks and no data/presentation reaching past the repository abstraction in either addition, consistent with priority item #1 in the ranked list below (both follow the abstract-class+Impl+Provider convention this audit already calls out as correct, not an ISP violation). `OrganizationRepository` bundles org CRUD, member management, cost-field CRUD, and pending-approval reads in one interface — worth checking against the same "fat interface" lens as `SocialRepository` (priority #2) in a future pass, but not verified in depth here.

> **2026-08-11 addendum:** spot-checked the new `lib/features/work_mode/` feature (presentation-only, no domain/data layer — deliberately mirrors `OnboardingNotifier`'s shape, the established precedent for a per-user-scoped `SharedPreferences` flag). No DIP/domain-layer violations — it depends only on other presentation-layer providers (`auth_provider.dart`, `organization_provider.dart`) plus `sharedPreferencesProvider`, same seam `OnboardingNotifier` already uses.
> - **New SRP-adjacent finding (minor, not fixed here):** `WorkModeNotifier` is now a second, independently-maintained, structurally-identical copy of `OnboardingNotifier`'s pattern — per-user `SharedPreferences` key prefix, `_lastUserId` caching, `_sync()` on construction and on every `authNotifierProvider` change, reset-to-null on sign-out. A shared generic base (e.g. `PerUserBoolPreferenceNotifier(prefsKeyPrefix)`) would collapse both into one implementation. Same class of finding as the existing `_DateTimePickerField`/legal-page duplications in the ranked list below (#12) — worth folding into that cleanup pass rather than fixing in isolation.
> - **Confirms the existing OCP finding (#2, "KumoTheme → visuals," ranked list below) rather than adding a new one:** adding `KumoTheme.onyxGold` required touching the exact 4 files that finding already predicts (the enum, `theme.dart`'s scheme, `main.dart`'s switch, `brand.dart`'s logo switch) — a fifth `KumoTheme.values`-driven site (`profile_page.dart`'s theme-picker list) was deliberately *not* touched, since `onyxGold` is enforced-only and explicitly filtered out of that list. The lookup-table refactor that finding already recommends would still collapse this to one map entry.

> **2026-08-11 addendum:** spot-checked the new `lib/features/gamification/` feature (Stage 23, purely read-only — awards happen entirely in Postgres triggers, no new mutation code path in Flutter at all). No domain-layer framework leaks; `GamificationBadge`/`XpSummary` are pure data + arithmetic, zero Flutter dependencies. One real finding, caught and fixed before shipping rather than left for a later pass:
> - **`gamificationRepositoryProvider` was initially typed `Provider<GamificationRepositoryImpl>`** — the concrete class, not the abstract `GamificationRepository` — repeating the exact DIP pattern this doc already flags (see the `packing_provider.dart`/`rating_provider.dart` finding above). Fixed to the abstract type before commit. Prompted a repo-wide recount of that finding's actual scope: **11 repository providers** are typed to their concrete `Impl` class, not the 2 originally counted — see that finding's 2026-08-11 correction and the updated priority #9 below.

---

## 1. Single Responsibility Principle (SRP)

**Compliance.** Widget decomposition is generally good throughout — small, single-purpose private classes (`PostCard`, `ItineraryCard`, `SegmentCard`, `_ExpenseTile`, `_MessageBubble`, `_OnboardingSlide`, `_ChannelHeader`) that render one thing off narrow callback params, with zero Riverpod/network coupling. Usecases are consistently thin, one operation each. `CalculateSettlementsUseCase` cleanly separates pure computation from CRUD. File *length* is often misleading here — **`itinerary_detail_page.dart` at 2,574 lines is not a God Object**: it's ~25 small, cohesive widget classes in one file. That's a navigation/file-organization complaint, not an SRP violation.

**Violations — the real issue is cross-file duplication of business rules, not god-classes:**

| Where | What |
|---|---|
| `itinerary_detail_page.dart:135-148`, `:1408-1479`, `add_edit_item_page.dart:139-146`, `invite_member_page.dart:54-75` | Itinerary item/member mutation ("splice list, call generic `UpdateItineraryUseCase`") is hand-rolled independently at 4 call sites. No `AddItemUseCase`/`RemoveMemberUseCase` exists. |
| ~~`itinerary_detail_page.dart:869-932` vs `add_expense_page.dart:262-281`~~ | ✅ **Fixed (2026-08-11).** Expense-summary recalculation math *was* independently reimplemented twice — a real correctness risk, not just style. Unified behind `ExpenseSummary.adjustedBy()`; see priority item #5 below. |
| `discover_page.dart:53-116` vs `public_profile_page.dart:19-76` | Fork/like workflow duplicated, with **already-visible behavioral drift**: Discover confirms a fork with a dialog, PublicProfilePage doesn't. |
| `chat_remote_datasource.dart:133-185` (`sendMessage`), `profile_remote_datasource.dart:150-188` (`createPendingInvitation`) | Persistence + best-effort push/email side-effect dispatch bolted into one method each. |
| `itinerary_detail_page.dart:1900-1946` (`_StatusRow._publish`) | Sequences two usecases from the widget (publish, then conditionally flip `isPublic`), including a documented provider-staleness workaround — this orchestration belongs in one usecase. |
| `travel_itinerary.dart` (whole file) | `TravelItinerary` embeds `ExpenseSummary` directly — a computed aggregate that conceptually belongs to `expense_split`, which already owns `Expense`/settlement logic. Two features now share one entity's reason to change. |
| `add_edit_item_page.dart:267-299` = `add_edit_trip_segment_page.dart:373-404` | `_DateTimePickerField` defined twice, near-identically. |
| `privacy_policy_page.dart:179-249` = `terms_page.dart:182-234` | `_Heading`/`_Section`/`_Body` byte-for-byte duplicated across both legal pages. |
| `edit_profile_page.dart:159-382` | One `State` class does direct Supabase Storage I/O, city/country autofill business rules, *and* two-repository save orchestration — at least 4 responsibilities. |
| `core/utils/validators.dart`, `core/utils/formatters.dart`, `config/constants.dart` | Grab-bag static classes spanning unrelated domains (auth + expense + itinerary validation in one `Validators`; a hardcoded US-only phone formatter sitting next to currency formatting). `AppConstants` is also only partially adopted (most datasources hardcode their own `_table` string instead) and contains **stale constants for tables that don't exist** in the real schema (`usersTable`, `groupsTable`, `groupMembersTable`, `itineraryEventsTable`). |

---

## 2. Open/Closed Principle (OCP)

**Compliance.** Dart's exhaustive `switch` over sealed types/enums (`Failure`, `ItineraryStatusEnum`, `TransportMode`, `SplitMode`) is the *correct*, low-cost tool here — not a violation. The standout good pattern: `profile_page.dart`'s `_kThemeMeta`/`_kMapProviderMeta` const maps let the theme/map-provider pickers render purely by lookup — adding a variant needs one map entry, not new branching logic.

**Violations — the "one enum, N files" fan-out, with no compiler link tying the copies together:**

- **`TransportMode` → rendering**, independently switched in 4 files with no shared table: `route_map_view.dart` (icon), `route_texture.dart` (texture/tick-count), `route_line_painter.dart` (paint), `route_marker_bitmaps.dart` (bitmap). Each is individually exhaustive, but a mode added to the enum compiles fine everywhere and just silently renders wrong in whichever file you forgot.
- **`KumoTheme` → visuals**, the same shape across 4 files: the enum, `theme.dart`'s `ColorScheme` getters, `main.dart`'s `MaterialApp.theme` switch, `brand.dart`'s logo switch.
- **`ItineraryStatusEnum` → (label, color)** duplicated independently in `itinerary_card.dart`'s `_StatusChip` and twice more in `itinerary_detail_page.dart`.
- **`GroupMemberRole`** rendering/semantics scattered across `_RoleChip`, a popup-menu switch, and `invite_member_page.dart`'s role dropdowns.
- **`ExpenseCategory`** icon switch duplicated between `_ExpenseTile` and the category picker.
- `TripTheme.resolve()` (domain) is a hand-written if-chain over keyword lists — adding a destination theme means editing 3 places in one file.

**Fix direction for all of the above:** collapse each into a single `Map<Enum, VisualSpec>` (or record) that every consumer reads from — turns "edit N files" into "add one map entry."

---

## 3. Liskov Substitution Principle (LSP)

**This is the strongest principle in the codebase — no real violations found anywhere.**

- Every `*Model extends *Entity` pair (10+ pairs checked) only *adds* `fromJson`/`toJson`/`fromEntity`; none overrides inherited behavior or `props`. A `Model` is always safely substitutable for its base entity.
- The one thing worth investigating in depth — entities' `copyWith` returns the *base* type, so `someModel.copyWith(...)` yields a plain entity, not a `Model` — was traced end-to-end and confirmed **safe**: every repository re-wraps via `Model.fromEntity()` before serializing, so nothing ever calls `.toJson()` on a bare `copyWith()` result. Misuse would fail to *compile*, not misbehave at runtime.
- Domain entities extend only `Equatable`, so there's no domain-internal subtyping to break.
- All `AsyncValue.when()` usage is exhaustive; all `dispose()` overrides call `super.dispose()`.

**One soft note (not a true LSP violation):** `edit_profile_page.dart:69,410` types its profile parameter as `dynamic` and accesses members at runtime, instead of the `UserProfile?` type already used everywhere else — this erases the compiler's ability to catch a broken contract, even though nothing is actually broken today.

---

## 4. Interface Segregation Principle (ISP)

**Compliance.** Most repository/datasource interfaces are small and cohesive (`PackingRepository`, `ExpenseRemoteDataSource`, `TripSegmentRepository`). Widget constructors stay minimal (`PostCard`, `ItineraryCard`). **Important calibration point used consistently across all 5 passes:** this codebase's single-method `abstract class X { ... } / class XImpl implements X` pairs (e.g. `AiGenerationRepository`, `GeocodingService`, `PremiumFeatureDataSource`) are deliberate DI seams, not ISP violations — ISP is about interfaces being too *fat*, not too thin. The linter's "unnecessary abstract class" suggestion on these is unrelated to ISP and should be ignored.

**Violations — genuinely fat interfaces bundling unrelated concerns:**

- **`SocialRepository`** (8 methods) bundles three separable concerns — publish/fork (`publishItinerary`, `fetchExplore`, `fetchFeed`, `fetchPostsByAuthor`, `forkPost`), likes (`toggleLike`), and the follow graph (`toggleFollow`, `fetchFollowStats`). No single consumer needs all 8 (`PublicProfilePage` never calls `publishItinerary`/`forkPost`). **Recommend splitting now, while it's new**, into a post/fork repository and a follow repository.
- **`UserProfileRepository`** bundles profile CRUD with notification-preference CRUD — `NotificationPreferencesPage` depends on the whole interface just to toggle a preference. Recommend a separate `NotificationPreferenceRepository`.
- **`ChatRepository.upsertPushToken`** has nothing to do with chat messages — it's device/token registration that happens to be called from chat today. Recommend moving it to `core/notifications`.
- `invite_member_page.dart`'s `_SearchTab`/`_EmailTab` each depend on the *full* `ProfileRemoteDataSource` interface to call exactly one method.
- Lower priority (cohesive today, only a risk if a narrower consumer shows up later): `AuthRepository` (12 methods) and `AuthRemoteDataSource` (13 methods).

---

## 5. Dependency Inversion Principle (DIP)

**Compliance.** The large majority of the codebase does this correctly: usecases/entities depend on zero data/presentation imports (verified by grepping every domain-layer import); repository implementations take datasources via constructor injection typed to the *interface*; Riverpod providers wire concretions once at the DI edge and everything downstream depends on the abstraction (`geocoding_providers.dart`, `premium_providers.dart`, `social_provider.dart`, `user_profile_provider.dart` are all textbook examples).

**Violations — this is the single largest cluster of findings across the whole audit, and the one thing worth fixing systemically rather than file-by-file:**

**Presentation code reaching past its repository abstraction:**
- `auth_provider.dart:37` — `authRepositoryProvider` is typed `Provider<AuthRepositoryImpl>` (concrete), not the abstract `AuthRepository` that already exists. `AuthNotifier` then calls the concrete repository directly for `getCurrentUser`/`resetPassword`/`logout`/`updateProfile`, while using proper usecases for `login`/`signup`/`deleteAccount` — an inconsistent DIP application *inside one class*.
- `password_reset_page.dart:36` — calls `ref.read(authRepositoryProvider)` directly from the widget; no `SendPasswordResetUseCase` exists at all, unlike every sibling auth flow.
- `invite_member_page.dart:15-17,93-97,189-192,343` — defines its own page-local `_profileDataSourceProvider` and calls `ProfileRemoteDataSource` methods directly, with no domain layer above it at all. The one screen that bypasses usecases entirely.
- `privacy_settings_page.dart:15-97` — defines a local provider wrapping a cross-feature datasource (`ProfileRemoteDataSourceImpl`, imported from the `itinerary` feature) with a raw try/catch, **in the same file** where `_updateVisibility` correctly uses the `Either<Failure,...>` convention. Two incompatible error-handling architectures side by side.
- `edit_profile_page.dart:159-194` — calls `Supabase.instance.client.storage` directly for avatar upload instead of going through a datasource, unlike every other Supabase interaction in the app.
- `chat_page.dart:76,277,284` and `auth_provider.dart:111` — call `KumoSupabaseClient` (the app's data-layer network seam) directly from presentation code for realtime channels, storage upload, and auth-state listening.
- `packing_provider.dart:14`, `rating_provider.dart:17` — repository providers typed to the concrete `Impl` class rather than the abstract interface (latent today, same footgun as auth's, not yet exploited). **2026-08-11 correction: this is far more widespread than originally counted.** A repo-wide grep for the pattern (`Provider<X RepositoryImpl>`) found **11 instances**, not 2 — also `organization_provider.dart`, `chat_provider.dart`, `itinerary_provider.dart`, `trip_email_alias_provider.dart`, `trip_segment_provider.dart`, `ai_generation_provider.dart`, `expense_provider.dart`, plus `auth_provider.dart` above. This is effectively the dominant convention across the codebase's repository providers, not a couple of stragglers — worth treating as one systemic pass (priority #9 below), not a 2-file fix. `gamification_provider.dart` (Stage 23) was caught making the same mistake on its first pass and fixed before shipping — the one new instance since this finding was first written.
- `inbox_page.dart:44` — calls `SharedPreferences.getInstance()` directly instead of the already-provided `sharedPreferencesProvider`.

**Data-layer inconsistencies:**
- `itinerary_repository_impl.dart` — `localDataSource` is typed to the *concrete* `ItineraryLocalDataSource` (which has no abstract interface at all), inconsistent with the same file's `remoteDataSource` field, which is correctly interface-typed.
- `rating_remote_datasource.dart:15` — reaches `Supabase.instance.client` directly instead of `KumoSupabaseClient`, the seam every other datasource uses.

**Backwards dependency direction:**
- `core/notifications/notification_service.dart` and `push_message_handler.dart` both `import '../../config/router.dart'` and hardcode a chat-route navigation decision inside a low-level plugin wrapper — a low-level module depending on a high-level policy module, the inverse of what DIP asks for. The same tap→route decision is also duplicated between the two files.

---

## Cross-cutting themes (read this if nothing else)

1. **DIP erosion at the presentation↔data boundary is the single most common finding across all 5 passes.** It's not architectural rot — most of the codebase gets this right — but there's a repeating pattern of "this one screen/provider reaches one layer too far" (auth, invite, privacy settings, avatar upload, chat realtime, packing/ratings providers, inbox prefs, one datasource). Worth a single pass to retype every repository provider to its abstract interface and route the handful of direct-Supabase/direct-datasource call sites through proper usecases.
2. **The "one enum, N files" OCP pattern** (TransportMode, KumoTheme, ItineraryStatusEnum, GroupMemberRole, ExpenseCategory) shows up repeatedly wherever a new visual/behavioral variant needs multiple files updated in lockstep with no compiler link between them. A lookup-table refactor per enum would remove this risk permanently.
3. **LSP is a genuine strength** — worth knowing you don't need to worry about this one; the Model/Entity inheritance pattern is used correctly everywhere.
4. ✅ **Fixed (2026-08-11)** — was the one clear Clean Architecture breach: `lib/features/itinerary/domain/entities/trip_theme.dart` imported `flutter/material.dart` and had a `withContext(BuildContext)` method — a domain entity depending on the UI framework, contradicting this project's own CLAUDE.md. `withContext` now lives in a presentation-layer extension; see priority item #1 below.
5. **SocialRepository is new code and easiest to fix now**, before more consumers accrete against its 3-concerns-in-1-interface shape.

## Ranked, deduplicated priority list

1. ✅ **Fixed (2026-08-11).** Moved `TripTheme.withContext()` out of the domain entity into a new presentation-layer extension, `TripThemeContextX` (`lib/features/itinerary/presentation/extensions/trip_theme_context_extension.dart`). The entity's `import 'package:flutter/material.dart'` was narrowed to `import 'package:flutter/painting.dart' show Color, LinearGradient` — the plain, context-free paint-value types the entity's other getters (`headerGradient`/`cardBarGradient`) still legitimately need — rather than the widget/`BuildContext`/`Theme` machinery `withContext` required. New test: `test/features/itinerary/presentation/extensions/trip_theme_context_extension_test.dart`.
2. Split `SocialRepository` into post/fork + follow (± like) repositories while it's still new.
3. Fix Auth's mixed DIP story: retype `authRepositoryProvider`/`AuthNotifier.repository` to the abstract `AuthRepository`, and give password-reset a real usecase.
4. Fix `InviteMemberPage` and `PrivacySettingsPage` — the two screens that bypass usecases/the `Either` convention entirely.
5. ✅ **Fixed (2026-08-11).** Unified the two independent expense-summary recalculation implementations behind a new `ExpenseSummary.adjustedBy({categoryKey, delta})` domain-entity method — `add_expense_page.dart`'s add path and `itinerary_detail_page.dart`'s delete path now both call it (with a positive/negative delta respectively) instead of each hand-rolling the category-map/total mutation. Also closed a real latent bug this surfaced: the add path had no clamping to non-negative at all (only the delete path did) — both now share the same clamp. New test: `test/features/itinerary/domain/entities/expense_summary_test.dart`.
6. Collapse the `TransportMode`/`KumoTheme` rendering fan-out (4 files each) into lookup tables.
7. Extract `edit_profile_page.dart`'s direct Storage call and `chat_page.dart`'s direct Supabase calls behind their repositories.
8. Decouple `core/notifications` from `config/router.dart` — emit tap events, let one place own navigation.
9. Blanket-retype repository providers to their abstract interfaces — **11 instances found (2026-08-11 recount), not the original 2**: `packing`, `ratings`, `organization`, `chat`, `itinerary`, `trip_email_alias`, `trip_segment`, `ai_generation`, `expense`, plus `auth` (priority #3 above covers auth's fix specifically). Cheap per-file (a type annotation change, the constructor call itself doesn't move), but now sized like a real pass across ~10 files rather than a quick two-file cleanup.
10. Clean up `AppConstants` (delete stale table constants for tables that don't exist) and split the `Validators`/`Formatters` grab-bags by owning domain.
11. Move `ChatRepository.upsertPushToken` to `core/notifications`; split `UserProfileRepository`'s notification-preference methods out.
12. Dedupe: `_DateTimePickerField` (2 copies), legal-page section widgets (2 copies), fork/like workflow (Discover vs. PublicProfile, already drifted).
