# Kumo Project Documentation

**Project:** Kumo - Collaborative Travel Super-App  
**Version:** 1.0.0  
**Last Updated:** June 2026

---

## Quick Start

### Prerequisites
- Flutter 3.13+
- Dart 3.12+
- Supabase account
- (Optional) Xcode for iOS, Android Studio for Android

### Setup

```bash
# Clone the repo
git clone <repo-url>
cd kumo_claude

# Install dependencies
flutter pub get

# Generate code (Riverpod, Isar, etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# Create .env file
cp .env.example .env
# Edit .env with your Supabase credentials

# Run the app
flutter run
```

---

## Architecture Overview

### Clean Architecture Layers

Kumo follows **Clean Architecture** with three distinct layers:

#### 1. **Domain Layer** (`lib/features/{feature}/domain/`)
- **Purpose:** Business logic, independent of frameworks
- **Contains:** Entities, repositories (abstract), usecases
- **No dependencies:** On data layer, presentation, or external libraries
- **Example:** `lib/features/auth/domain/entities/user.dart`

#### 2. **Data Layer** (`lib/features/{feature}/data/`)
- **Purpose:** Fetch and persist data from external sources
- **Contains:** Models, datasources (local/remote), repository implementations
- **Dependencies:** Domain layer only (via interfaces)
- **Example:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

#### 3. **Presentation Layer** (`lib/features/{feature}/presentation/`)
- **Purpose:** UI, state management, user interactions
- **Contains:** Pages, widgets, Riverpod providers
- **Dependencies:** Domain layer (usecases, entities)
- **State Management:** Riverpod (functional, reactive, testable)
- **Example:** `lib/features/auth/presentation/pages/login_page.dart`

### Why This Architecture?

✅ **Testability:** Each layer can be tested independently  
✅ **Maintainability:** Clear separation of concerns  
✅ **Scalability:** Easy to add new features without touching existing code  
✅ **Reusability:** Domain logic is framework-agnostic  
✅ **Flexibility:** Swap implementations (e.g., Supabase → REST API) without affecting domain

---

## State Management: Riverpod

### Why Riverpod?

- **Functional Reactivity:** No event/state classes, just functions
- **Dependency Injection:** Built-in, compile-time safe
- **Testability:** Override providers in tests with `.overrideWithValue()`
- **Performance:** Fine-grained reactivity; only affected widgets rebuild
- **Async Support:** First-class `AsyncValue` for loading/error/data states

### Provider Types

#### 1. **StateNotifier** (for complex state)
```dart
class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);

  void increment() => state++;
}

final counterProvider = StateNotifierProvider((ref) => CounterNotifier());
```

#### 2. **FutureProvider** (for async operations)
```dart
final userProvider = FutureProvider((ref) async {
  return await ref.read(authRepositoryProvider).getCurrentUser();
});
```

#### 3. **StateProvider** (for simple state)
```dart
final nameProvider = StateProvider((ref) => '');
```

#### 4. **StreamProvider** (for streams)
```dart
final messagesProvider = StreamProvider((ref) {
  return supabaseClient.from('messages').stream();
});
```

### Example: Auth State Management

```dart
// Domain: Usecase
class LoginUseCase {
  Future<Either<Failure, User>> call(String email, String password) { ... }
}

// Presentation: Provider
final authProvider = StateNotifierProvider((ref) {
  final usecase = ref.watch(loginUsecaseProvider);
  return AuthNotifier(usecase);
});

// Widget: Usage
Consumer(builder: (context, ref, child) {
  final auth = ref.watch(authProvider);
  
  return auth.when(
    loading: () => LoadingWidget(),
    error: (err, st) => ErrorWidget(err),
    data: (user) => HomeWidget(user),
  );
});
```

---

## Folder Structure

```
lib/
├── config/                          # App configuration
│   ├── constants.dart              # Constants (timeouts, table names, etc.)
│   ├── environment.dart            # Environment-specific config
│   └── theme.dart                  # Material 3 theme
├── core/                           # Shared infrastructure
│   ├── error/
│   │   ├── exception.dart         # Exception classes
│   │   └── failure.dart           # Failure sealed class (type-safe errors)
│   ├── network/
│   │   └── supabase_client.dart   # Supabase initialization & wrapper
│   ├── utils/
│   │   ├── validators.dart        # Input validation utilities
│   │   ├── logger.dart            # Logging wrapper
│   │   └── formatters.dart        # Currency, date, number formatting
│   └── shared_preferences/         # Local storage wrapper (Stage 1+)
├── features/                       # Feature-based modules
│   ├── auth/                       # Authentication feature
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_remote_datasource.dart
│   │   │   │   └── auth_local_datasource.dart
│   │   │   ├── models/
│   │   │   │   └── user_model.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   │       ├── login_usecase.dart
│   │   │       ├── signup_usecase.dart
│   │   │       └── logout_usecase.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── login_page.dart
│   │       │   ├── signup_page.dart
│   │       │   └── password_reset_page.dart
│   │       ├── widgets/
│   │       │   ├── email_input_field.dart
│   │       │   └── password_input_field.dart
│   │       └── providers/
│   │           └── auth_provider.dart
│   ├── itinerary/                  # Itinerary feature
│   │   ├── data/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── travel_itinerary.dart
│   │   │   ├── repositories/
│   │   │   │   └── itinerary_repository.dart
│   │   │   └── usecases/
│   │   │       ├── fetch_itinerary_usecase.dart
│   │   │       ├── create_itinerary_usecase.dart
│   │   │       └── update_itinerary_usecase.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       ├── widgets/
│   │       └── providers/
│   ├── chat/                       # Real-time chat (Stage 2+)
│   ├── expense_split/              # Expense splitting (Stage 4+)
│   ├── ai_generation/              # AI itinerary generation (Stage 3+)
│   └── [other features...]
├── shared/                         # Shared UI & utilities
│   ├── extensions/
│   │   └── context_extensions.dart # Shortcuts like context.theme
│   ├── mixins/
│   ├── widgets/
│   │   ├── app_scaffold.dart
│   │   ├── loading_widget.dart
│   │   └── error_widget.dart
│   └── animations/
└── main.dart                       # App entry point
```

---

## Error Handling Strategy

### Exceptions vs. Failures

- **Exceptions:** Thrown for unexpected errors (crash-level)
- **Failures:** Returned as `Either<Failure, T>` for expected errors (domain-level)

### Exception Hierarchy

```dart
KumoException
├── NetworkException
├── AuthException
├── ServerException
├── ValidationException
├── NotFoundException
├── LocalStorageException
└── UnexpectedException
```

### Failure Sealed Class

```dart
sealed class Failure extends Equatable {
  final String message;
  // ...
}

class NetworkFailure extends Failure { }
class AuthFailure extends Failure { }
class ServerFailure extends Failure { }
// ... more failure types
```

### Usage Pattern

```dart
// Repository returns Either<Failure, T>
Future<Either<Failure, User>> login(String email, String password) async {
  try {
    final user = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return Right(userFromSupabaseUser(user.user!));
  } on AuthException catch (e) {
    return Left(AuthFailure.invalidCredentials());
  } on NetworkException catch (e) {
    return Left(NetworkFailure.noInternet());
  }
}

// Use in presentation
final result = await loginUsecase(email, password);
result.fold(
  (failure) => showErrorSnackbar(failure.message),
  (user) => navigateToHome(),
);
```

---

## Testing Strategy

### Three-Tier Pyramid

```
        E2E Tests (UI flows)           5%
       Widget Tests (UI rendering)    15%
      Unit Tests (business logic)     80%
```

### Test File Organization

```
test/
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       └── login_usecase_test.dart
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl_test.dart
│   │   └── presentation/
│   │       └── pages/
│   │           └── login_page_test.dart
│   └── itinerary/
│       └── ...
└── utils/
    └── test_helpers.dart
```

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/features/auth/domain/usecases/login_usecase_test.dart

# Watch mode
flutter test --watch
```

---

## Conventions & Best Practices

### Naming

- **Classes:** PascalCase (`AuthRepository`, `LoginUseCase`)
- **Variables/Functions:** camelCase (`currentUser`, `getItineraries()`)
- **Constants:** UPPER_SNAKE_CASE (`MAX_PASSWORD_LENGTH`)
- **Files:** snake_case (`auth_repository.dart`)
- **Prefixes:** Use meaningful prefixes
  - `_private` for private members
  - `is` for booleans (`isAuthenticated`, `isEmpty`)
  - `on` for event handlers (`onTap`, `onChanged`)

### Comments & Documentation

- **Public APIs:** Use `///` (Dartdoc) with `@param`, `@returns`, `@throws`
- **Complex Logic:** Inline comments explaining "why", not "what"
- **No Noise:** Remove comments that just reiterate code
- **Example:**
  ```dart
  /// Validates email format using RFC 5322 regex.
  ///
  /// @param email The email to validate
  /// @returns true if valid, false otherwise
  /// @throws ValidationException if email is empty
  bool validateEmail(String? email) { ... }
  ```

### Imports

- **Group imports:** Dart → Flutter → Packages → Local
- **Avoid:** Wildcard imports (`import '.../*'`)
- **Example:**
  ```dart
  import 'dart:async';
  
  import 'package:flutter/material.dart';
  import 'package:riverpod/riverpod.dart';
  
  import 'package:kumo_claude/core/error/failure.dart';
  import 'features/auth/domain/repositories/auth_repository.dart';
  ```

### Code Style

- **Formatting:** Use `dart format` (run via `flutter format`)
- **Analysis:** Run `flutter analyze` regularly
- **Null Safety:** Use non-null by default; `?` only when necessary
- **Const:** Use `const` for immutable values and widgets

### Avoid

- ❌ Naked Futures (always handle with `.then()`, async/await, or Riverpod)
- ❌ Mutable global state (use Riverpod providers instead)
- ❌ Deep nesting (extract functions/widgets)
- ❌ Overly broad exception catching (catch specific exceptions)
- ❌ Synchronous blocking calls on main thread

---

## Development Workflow

### Adding a New Feature

1. **Start with Domain:** Define entities and repository interface
2. **Write Tests:** Test-driven development (TDD) first
3. **Implement Data:** Datasources and repository implementation
4. **Add Presentation:** Pages, widgets, Riverpod providers
5. **Integration Test:** Full flow in test environment
6. **Code Review:** Peer review before merge

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/user-profile

# Commit with meaningful messages
git commit -m "Add user profile page with edit functionality"

# Push and create PR
git push origin feature/user-profile
# Create PR on GitHub
```

### CI/CD Pipeline

- Pre-commit hooks: `dart format`, `flutter analyze`
- Pull request: Unit tests, code coverage
- Merge to main: Deploy to staging
- Release tag: Deploy to production

---

## Performance Optimization

### Tips

- **Lazy Load:** Don't load all itineraries at once; use pagination
- **Cache:** Isar local cache for frequently accessed data
- **Riverpod:** Use fine-grained providers to minimize rebuilds
- **Images:** Lazy load, use `Image.network` with caching
- **Profiles:** Use `flutter analyze` and DevTools for performance insights

### Benchmarks

- **Target:** UI frame rate 60 FPS (16ms per frame)
- **API Calls:** <2s max (target <500ms)
- **UI Load:** <1s from tap to render

---

## Security Best Practices

- **Tokens:** Store in secure Keychain/Keystore, never log
- **HTTPS Only:** No HTTP fallback
- **Secrets:** Use `.env` files; never commit to git
- **Input Validation:** Validate at boundaries (user input, API responses)
- **Error Leaking:** Don't expose sensitive details in error messages

---

## Deployment

### Environments

```
Development → Staging → Production
  (debug)    (release)   (release)
```

### Build & Release

```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release

# App Store
cd ios && fastlane deploy_app_store

# Google Play
cd android && fastlane deploy_google_play
```

---

## Platform Implementation Details

### Theming System

Kumo supports six visual themes: **Cherry Blossom**, **Golden Hour**, **Deep Voyage** (default), **Synthwave Tokyo**, **White & Charcoal**, and **Warm Oat & Light Blue** (added in Stage 19).

- **Enum & provider:** `lib/config/theme_provider.dart` — `KumoTheme` enum + `ThemeNotifier extends StateNotifier<KumoTheme>`
- **Persistence:** SharedPreferences key `kumo_theme` stores `KumoTheme.name`; loaded in `ThemeNotifier` constructor via `_loadSaved()`
- **UI:** Theme picker is a bottom sheet on the Profile page (`lib/features/shell/profile_page.dart`); opened via `isScrollControlled: true, useSafeArea: true`
- **Launcher icon:** Fixed as Deep Voyage on both platforms. Runtime icon switching via `PackageManager.setComponentEnabledSetting()` was removed because it clears the Android task stack (the app appears to close).
- **Dark theme:** Synthwave Tokyo (`lib/config/theme.dart`, `_synthwaveScheme`) is the app's first `Brightness.dark` theme — magenta-purple dusk sky with an orange/gold sunset accent. All other five themes are `Brightness.light`.
- **Stage 19 fix:** the shell bottom nav bar and `OfflineBanner` had Cherry-Blossom colors hardcoded instead of reading from `Theme.of(context)`, which silently broke visuals under every other theme. Fixed to pull from the active `ColorScheme`.

### Router Architecture

**File:** `lib/config/router.dart`

GoRouter is created **once** per app lifetime using the `_RouterNotifier` pattern:

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [ /* ... */ ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref
      ..listen<AuthState>(authNotifierProvider, (prev, next) => notifyListeners())
      ..listen<bool?>(onboardingProvider, (prev, next) => notifyListeners());
  }
  // ...
}
```

**Why not `ref.watch` at the top level?** Watching reactive state inside `Provider` rebuilds the entire provider value — i.e. creates a new `GoRouter` — whenever auth or onboarding state changes. A new GoRouter resets to `initialLocation: '/splash'`, causing the splash screen to appear multiple times (after login, after skipping onboarding, etc.). `_RouterNotifier` + `refreshListenable` keeps one GoRouter alive and only triggers `redirect` re-evaluation.

**Redirect rules:**
- `/splash` is never redirected — the splash page controls its own navigation
- Unauthenticated users outside auth routes → `/login`
- Authenticated users on auth routes → `/onboarding` (if not completed) or `/home`
- Password recovery state → `/reset-password`

### Android Splash Screen Architecture

Two layers cover different API levels:

#### Pre-Android 12 (API < 31)

- `styles.xml` `LaunchTheme.windowBackground` → `@drawable/launch_background`
- `drawable/launch_background.xml` and `drawable-v21/launch_background.xml` → single `<bitmap gravity="fill" src="@drawable/background"/>`
- `background.png` is a **manually generated** portrait image (1080 × 2400 px) with the same radial gradient as the app icon (`centre #16294D → edges #0E1B33`), extended to full portrait dimensions so there is no visible seam around the icon.
- **Do not regenerate with `flutter_native_splash:create`** — it would overwrite `background.png` with a flat colour.

#### Android 12+ (API 31+)

- OS splash is controlled by `windowSplashScreenAnimatedIcon` in `values-v31/styles.xml`
- Points to `@drawable/android12splash` — **transparent RGBA PNGs** (logo strokes only, no background)
- `windowSplashScreenIconBackgroundColor` = `#0E1B33` fills the icon circle; same colour used for outer background, so no visible ring
- Files: `drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/android12splash.png` (and `-night-` variants)
- `colors.xml` `splash_background` = `#0E1B33` (used by `NormalTheme` during Flutter engine init)

**Key constraint:** Android 12 OS splash is always the same regardless of the user's selected in-app theme; it cannot be changed at runtime.

### Icon & Asset Generation Script

**File:** `scripts/gen_icons.py`

Run to regenerate all icon assets after changing source SVGs or theme colours:

```bash
python3 scripts/gen_icons.py
```

`generate_alternate_icons()` produces per-theme:
- `drawable-{mdpi…xxxhdpi}/ic_launcher_foreground_{theme}.png` — adaptive icon foreground at 108–432 px
- `drawable/ic_launcher_background_{theme}.xml` — per-theme gradient XML
- `mipmap-anydpi-v26/ic_launcher_{theme}.xml` — adaptive icon descriptor
- `mipmap-{mdpi…xxxhdpi}/ic_launcher_{theme}.png` — plain PNG fallback for API < 26

The default launcher icon (`ic_launcher`) remains Deep Voyage; alternate assets exist in the resource tree but are not activated at runtime.

### Extended User Profile (Stage 16)

**Migration:** `docs/supabase_migrations/stage16_extended_profile.sql`  
Must be run in Supabase SQL editor before deploying the corresponding app build.

#### Database schema additions

`public.profiles` gains these columns (all `add column if not exists`):

| Column | Type | Notes |
|--------|------|-------|
| `username` | `text` | Unique, case-insensitive (`lower(username)` unique index, NULLs distinct) |
| `bio` | `text` | |
| `city` | `text` | |
| `country` | `char(2)` | ISO 3166-1 alpha-2 |
| `timezone` | `text` | IANA tz string |
| `preferred_currency` | `char(3)` | ISO 4217 |
| `preferred_language` | `char(2)` | ISO 639-1 |
| `units_preference` | `text` | `'metric'` or `'imperial'`, NOT NULL default `'metric'` |
| `travel_preference_tags` | `text[]` | NOT NULL default `'{}'` |
| `profile_visibility` | `text` | `'public'` or `'private'`, NOT NULL default `'public'` |
| `contact_visibility` | `text` | `'collaborators_only'` or `'hidden'`, NOT NULL default `'collaborators_only'` |
| `username_last_changed_at` | `timestamptz` | Used for 7-day cooldown enforcement |
| `updated_at` | `timestamptz` | NOT NULL default `now()` |

**New tables:**
- `public.username_history` — one row per username change; owner-only read RLS
- `public.profile_change_log` — audit trail for field changes; owner-only read RLS
- `public.notification_preferences` — `(user_id, channel, category)` PK; owner-all RLS

**Notification channels:** `push`, `email`, `sms`  
**Notification categories:** `trip_invites`, `expense_activity`, `flight_alerts`, `collab_updates`, `marketing_engagement`  
All default `enabled = true` except `marketing_engagement` (GDPR opt-in → defaults `false`).

#### RPCs

**`update_profile(...)`** — `SECURITY DEFINER`, all params optional (default `null`):
- Uses `COALESCE(param, current_value)` — passing `null` leaves the column unchanged
- Username validation: format regex `^[a-zA-Z0-9][a-zA-Z0-9_]{1,28}[a-zA-Z0-9]$`, case-insensitive uniqueness, 7-day cooldown
- On username change: inserts into `username_history` and `profile_change_log` atomically
- The `username_last_changed_at` CASE expression in the UPDATE re-reads the column to detect a true change (avoids resetting the clock when `p_username` matches current value)

**`upsert_notification_preference(p_channel, p_category, p_enabled)`** — single-row upsert on the `(user_id, channel, category)` PK.

**`seed_notification_preferences(p_user_id)`** — called by the `handle_new_user` trigger on signup and once as a backfill for existing users. Uses `ON CONFLICT DO NOTHING` so it is idempotent.

#### Flutter layer

- **Entities:** `lib/features/profile/domain/entities/user_profile.dart` — `UserProfile extends Equatable` with computed `canChangeUsername` (7-day guard) and `nextUsernameChangeAt`
- **Entities:** `lib/features/profile/domain/entities/notification_preference.dart` — `NotifChannel` / `NotifCategory` constant classes + `NotificationPreference entity`
- **Repository interface:** `lib/features/profile/domain/repositories/user_profile_repository.dart`
- **Data layer:** `lib/features/profile/data/` — models, `UserProfileRemoteDataSourceImpl`, `UserProfileRepositoryImpl`
- **Providers:** `lib/features/profile/presentation/providers/user_profile_provider.dart` — `userProfileProvider` (`FutureProvider.autoDispose`), `notificationPreferencesProvider`, `userProfileRepositoryProvider`
- **Edit Profile page:** `lib/features/profile/presentation/pages/edit_profile_page.dart` — `ConsumerStatefulWidget`; sections: Identity (name, username + cooldown warning, bio), Avatar URL, Location, Preferences (SegmentedButton for units), Travel Interests (FilterChip grid); saves auth metadata + profiles table in sequence; invalidates `userProfileProvider` on success
- **Notification Preferences page:** `lib/features/profile/presentation/pages/notification_preferences_page.dart` — matrix UI (rows = categories, columns = channels); optimistic toggle with revert on failure; route `/profile/notifications`
- **Privacy Settings page:** extended with profile-visibility and contact-visibility `SwitchListTile` sections; reads from `userProfileProvider`, writes via `userProfileRepositoryProvider.updateProfile`

#### Key design decisions

- **UUID is the only stable FK.** `username` is mutable — never used as a foreign key anywhere in the schema. All relations use `user_id uuid`.
- **Two-store sync for display_name / avatar_url.** These fields exist in both `auth.users` metadata (drives `AuthAuthenticated.user` in the app) and `public.profiles`. `EditProfilePage._save()` calls `authNotifier.updateProfile()` first (auth metadata), then `userProfileRepository.updateProfile()` (profiles table).
- **Optimistic notification toggles.** `_PrefsBodyState` keeps a local `Map<(String, String), bool> _state`; on failure the RPC result reverts the local state and shows a snackbar.

### Expense Improvements (Stage 17)

**Migration:** `docs/supabase_migrations/stage17_expense_improvements.sql`  
Must be run in Supabase SQL editor before deploying the corresponding app build.

#### Database schema additions

Three new columns on `public.expenses` (all `add column if not exists`, backward-compatible defaults):

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `split_mode` | `text` | `'equal'` | `check in ('equal', 'percentage', 'ratio')` |
| `exchange_rate_to_base` | `numeric` | `1.0` | Multiplier: `expense_currency → trip base currency` |
| `is_settlement` | `bool` | `false` | True for cash settle-up payments; hidden from expense list |

#### Flutter layer

**Entities** (`lib/features/expense_split/domain/entities/expense.dart`):
- `enum SplitMode { equal, percentage, ratio }` — added at file level
- `Expense` gains: `splitMode`, `exchangeRateToBase`, `isSettlement` (all with safe defaults)
- `ExpenseSplit` gains: `rawValue` (optional double — stores the raw % or ratio value for display; not used in calculations)
- `Settlement` gains: `currencyCode` (always the trip base currency)

**Model** (`lib/features/expense_split/data/models/expense_model.dart`):
- `fromJson` uses `??` fallbacks to match the DB defaults; old rows without the new columns deserialise cleanly
- `rawValue` in splits is stored in the existing JSONB `splits` column — no schema change needed

**Use cases:**
- `CalculateSettlementsUseCase.call(expenses, {required String baseCurrency})` — multiplies each split's `shareAmount` by `expense.exchangeRateToBase` before accumulating net balances; skips settlement expenses so they cancel debt without double-counting
- `AddExpenseUseCase.call(...)` — accepts `splitMode`, `exchangeRateToBase`, `isSettlement` optional named params

**Providers** (`lib/features/expense_split/presentation/providers/expense_provider.dart`):
- `settlementsProvider` family param changed from `String itineraryId` to `(String itineraryId, String baseCurrency)` record — threads base currency into the calculator without a wrapper class

**Add Expense page** (`lib/features/expense_split/presentation/pages/add_expense_page.dart`):
- `_CurrencyPicker`: `DropdownButton<String>` over 25 common travel currencies
- `_SplitModeBar`: `SegmentedButton<SplitMode>` — Equal / Percent / Ratio
- `_SplitSection` + `_MemberSplitRow`: per-member `TextField` controllers for % or ratio input with live amount preview
- Exchange-rate field shown only when `expenseCurrency != itinerary.currencyCode`: `1 [currency] = [X] [baseCurrency]`
- Percentage mode validates that all member values sum to 100 ± 0.1% before allowing submit

**Itinerary detail page** (`lib/features/itinerary/presentation/pages/itinerary_detail_page.dart`):
- Expense list filters: `.where((e) => !e.isSettlement)` — settlement rows are hidden from the expense list and budget totals
- `_settleUp(BuildContext, WidgetRef, Settlement)` — shows a confirm dialog, records a cash payment as `is_settlement: true` expense with debtor as payer + creditor in splits; shows "Payment recorded" snackbar on success
- `_SettlementRow` — added "Mark paid" `TextButton` that triggers `_settleUp`

#### Key design decisions

- **No settlements table.** Cash payments are stored as `is_settlement = true` expense rows. The greedy debt-minimisation algorithm already handles this correctly — debtor-as-payer with creditor in splits cancels the net balance without any schema additions.
- **Multi-currency normalisation happens at the calculation layer only.** Raw `shareAmount` values stored in JSONB are always in the expense's own currency; the `exchangeRateToBase` multiplier is applied only inside `CalculateSettlementsUseCase` to produce base-currency net balances.
- **`rawValue` in splits.** Stores the user-entered % or ratio for the edit flow (currently write-only; an edit expense screen can use it to repopulate the split inputs). Not used in any financial calculation.

### Edit Profile Field Pickers (Stage 16 extension)

**Files:**
- `lib/features/profile/presentation/pages/profile_field_data.dart` — offline lookup lists: 190+ countries (ISO 3166-1 alpha-2), 75 timezones (IANA), 48 currencies (ISO 4217), 69 languages (ISO 639-1), 110+ cities with autofill metadata
- `lib/features/profile/presentation/pages/edit_profile_page.dart` — updated

**Changes to `EditProfilePage`:**
- Country, Timezone, Currency, Language fields replaced with `_PickerField` — a tappable `InputDecorator` row that opens a `_LookupSheet` modal bottom sheet
- `_LookupSheet`: `DraggableScrollableSheet` (75% initial, 95% max) with a live-search `TextField` and a `ListView.builder`; search filters by both name and ISO code; current selection highlighted with a checkmark; tapping an entry pops the sheet returning the ISO code
- Clearing: ✕ `IconButton` shown when a value is selected; sets the state var back to `null`
- The four `TextEditingController`s (`_countryCtrl` etc.) were removed; selected codes are held as `String?` state vars (`_country`, `_timezone`, `_currency`, `_language`); `_save()` passes them directly to `updateProfile()`
- City uses `RawAutocomplete<CityEntry>` with 110+ entries in `kCityData`; selecting a suggestion auto-fills Country, Timezone, Currency (always overwrites); free-text city names work normally with no autofill
- Selecting Country auto-fills Currency and Timezone via `kCityData` lookup using `??=` (only fills if the field is still empty)
- Avatar displayed as a 112 px `CircleAvatar` at the top; pencil overlay opens an action sheet (gallery, camera, URL, remove); images uploaded to Supabase Storage `avatars/{userId}/avatar.{ext}` with cache-busted public URL

### Avatar Storage + Profile Upsert Fix (Stage 18)

**Migration:** `docs/supabase_migrations/stage18_avatar_storage_and_profile_upsert.sql`  
Must be run in Supabase SQL editor.

#### What it does

**Avatars storage bucket:**
- Creates `storage.buckets` entry `(id='avatars', public=true)`
- RLS policies on `storage.objects`:
  - `avatars_public_read` — `SELECT` with no auth (avatar URLs are embedded in UI)
  - `avatars_owner_insert` / `_update` / `_delete` — scoped to `authenticated` where `(storage.foldername(name))[1] = auth.uid()::text`, meaning each user can only touch files under their own `{userId}/` prefix

**Backfill missing profile rows:**
- `INSERT INTO public.profiles (id, email, display_name) SELECT ... FROM auth.users WHERE NOT EXISTS (...)` — one-time fix for users who signed up before `handle_new_user` was deployed and have no profile row

**`update_profile` RPC upsert guard:**
- Adds `INSERT INTO public.profiles (id, display_name, email) ... ON CONFLICT (id) DO NOTHING` at the top of the function body, executed before the `UPDATE`
- Root cause of "Profile not found" error: the old RPC ran `UPDATE ... WHERE id = _uid` which silently matched 0 rows when the profile didn't exist; the follow-up `getOwnProfile()` then found 0 rows and threw `ServerException('Profile not found')`
- The upsert guard makes the function self-healing for any user without a profile row

#### Flutter-side error flow (for reference)

```
updateProfile()                          // datasource
  → rpc('update_profile', params)        // runs OK, upserts if needed
  → getOwnProfile()                      // re-fetches the updated profile
    → rows.isEmpty → throws ServerException('Profile not found')   ← fixed by migration
```

---

### Chat Upgrade, Dark Themes & Push Notification Foundation (Stage 19)

**Migration:** `docs/supabase_migrations/stage19_chat_upgrade.sql`  
Must be run in Supabase SQL editor before deploying the corresponding app build.

#### Database schema additions

- `messages.content` check constraint relaxed to `char_length between 0 and 4000` (attachment-only messages have no caption)
- `public.message_attachments` — one row per image/file attachment; `kind in ('image', 'file')`; RLS: readable by anyone who can read the parent message, insertable only by the message's own sender
- `chat-attachments` storage bucket — public read, writes restricted to the caller's own `{uid}/` prefix (same pattern as the Stage 18 `avatars` bucket)
- `public.message_reads` — per-user `(message_id, user_id, read_at)`; no direct client access, only through `SECURITY DEFINER` RPCs below. This sits alongside the existing `read_by text[]` array (Stage 15/16) rather than replacing it — `read_by` still drives the double-tick indicator, `message_reads` adds timestamped detail for the "who's seen this" view
- `notification_preferences` gains a `chat_messages` category (constraint updated); `profiles` gains `push_message_preview_enabled boolean default true`
- `public.push_tokens` — `(user_id, token, platform)` PK where `platform in ('ios', 'android')`; owner-all RLS

#### RPCs

- `mark_messages_read(p_itinerary_id)` — reissued to also upsert into `message_reads` alongside the existing `read_by` array append
- `get_message_read_receipts(p_message_id)` — sender-only; returns `(user_id, display_name, avatar_url, read_at)` for the long-press "message info" sheet
- `update_profile(...)` — reissued with a 14th param, `p_push_message_preview`; the old 13-param signature is explicitly dropped first (`create or replace` only matches identical parameter lists, so without the drop, Postgres would keep both as ambiguous overloads)
- `upsert_push_token(p_token, p_platform)` — single-row upsert on the `(user_id, token)` PK

#### Flutter layer

- **Chat UI (`lib/features/chat/presentation/pages/chat_page.dart`):** WhatsApp-style bottom-anchored message list with date dividers, photo attachment picker/viewer, long-press read-receipt bottom sheet
- **Entities:** `MessageAttachment` (`domain/entities/message_attachment.dart`), `MessageReadReceipt` (`domain/entities/message_read_receipt.dart`)
- **Notification Preferences page:** `chat_messages` push toggle added to the existing matrix; a separate "show message preview" toggle controls whether push/local notification bodies show the actual text or a generic "New message"
- **Dark themes:** see Theming System section above — three new themes added, including the app's first dark theme (Synthwave Tokyo)
- **App rename:** bundle/application ID changed to `com.cygnus.travelKumo` on both platforms (was needed to register a clean Firebase project)
- **Firebase project setup:** `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` added; `ios/Runner/AppDelegate.swift` calls `FirebaseApp.configure()`. This stage only wired up the Firebase *project* — actual push delivery (FCM token registration, the sending Edge Function, and iOS entitlements) was built out afterward, see below.

---

### Push Notification Delivery (Stage 19 extension)

Built on top of the Stage 19 Firebase project setup to actually deliver chat push notifications, rather than just showing a local notification while the app is open.

#### Architecture

- **Android:** data-only FCM messages throughout — no top-level FCM `notification` field — so `flutter_local_notifications` has full, consistent control over how a notification is displayed in every app state:
  - Foreground/backgrounded-but-alive → `chatMessageWatcherProvider`'s Realtime stream watch (`lib/features/chat/presentation/providers/chat_provider.dart`)
  - Backgrounded/killed → `firebaseMessagingBackgroundHandler` (`lib/core/notifications/push_message_handler.dart`), registered via `FirebaseMessaging.onBackgroundMessage` in `main.dart`, runs in a separate isolate and calls `flutter_local_notifications` directly
  - Both paths converge on the same tap callback (`NotificationService._onTap`), navigating to `/trip/:id/chat`
  - `_maybeNotify` in `chat_provider.dart` only fires the foreground/Realtime path when the app is actually resumed (`WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed`) — otherwise the backgrounded FCM handler would double up with it
- **iOS:** a real `apns.payload.aps.alert` block instead of data-only, sent from the same Edge Function. Apple gives silent/data-only background pushes no delivery guarantee — in particular they are not delivered once the user force-quits the app — so the Android approach of "app renders its own notification" doesn't transfer. An OS-displayed alert has no such gap. Tap handling for it is separate: `FirebaseMessaging.onMessageOpenedApp` + `getInitialMessage()`, wired in `main.dart`, calling `handleIosPushTap` in `push_message_handler.dart` (flutter_local_notifications is never involved on the alert path, so its tap callback can't cover it)
- **iOS is gated behind `kIosPushReady`** (`lib/core/notifications/push_config.dart`), currently `false`. Flip it once both are done:
  1. An APNs key is uploaded in the Firebase console (Project settings → Cloud Messaging → Apple app configuration)
  2. The Push Notifications capability is enabled for the Runner target in Xcode (regenerates the provisioning profile to include it)

  `ios/Runner/Runner.entitlements` (`aps-environment`) already exists and is wired into all three build configs via `CODE_SIGN_ENTITLEMENTS` in `project.pbxproj` — confirmed with a real `flutter build ios --no-codesign` (this project uses Swift Package Manager for iOS plugin integration, not CocoaPods, so no `Podfile` is involved).

#### Edge Function: `supabase/functions/send-message-push`

Invoked by `ChatRemoteDataSourceImpl.sendMessage` right after a successful `messages` insert — best-effort; the message itself has already landed regardless of whether the push succeeds.

- Verifies the caller's JWT and that they are the message's own sender (prevents spoofing a push on someone else's behalf)
- Recipients = itinerary owner + members, minus the sender. The `members` JSONB array mixes key casing depending on which code path wrote the entry — `handle_new_user` uses `userId`, the Flutter client's invite flow uses `user_id` (see Stage 11/13) — so both `m.userId` and `m.user_id` must be checked, or client-invited members silently get no push
- Filtered by the recipient's `chat_messages` / `push` notification preference (default enabled) and, per-recipient, `push_message_preview_enabled` controls whether the body shows real message content or a generic "New message"
- FCM auth uses a service-account OAuth2 flow implemented with Deno's native Web Crypto (RS256-signed JWT bearer assertion) — no third-party JWT dependency
- Stale tokens (FCM `UNREGISTERED`/`NOT_FOUND`/`INVALID_ARGUMENT`) are deleted from `push_tokens` after a failed send

**Required secret (set once):**
```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'
```

**Deploy:**
```bash
supabase functions deploy send-message-push
```

#### Token registration

`fcmTokenSyncProvider` (`lib/core/notifications/notification_providers.dart`) requests permission, fetches the FCM token, and keeps it registered via `upsert_push_token` for as long as the user is authenticated, re-registering on `FirebaseMessaging.instance.onTokenRefresh`. Runs for Android always; for iOS only once `kIosPushReady` is `true`.

#### Key design decisions

- **Data-only for Android, alert-only for iOS** is a deliberate platform split, not an inconsistency — see Architecture above.
- **No dependency on a notification-sending queue or cron.** Push is fired synchronously (fire-and-forget from the client's point of view) right after the message insert; a failure there never blocks or fails the send.
- **`push_tokens` is a public multi-row table per user** (a user can have several devices), never a single column on `profiles` — matches how `username_history`/`profile_change_log` were modeled as separate tables in Stage 16 rather than bolted onto `profiles`.

---

## Useful Resources

- [Clean Architecture](https://resocoder.com/flutter-clean-architecture)
- [Riverpod Documentation](https://riverpod.dev)
- [Supabase Flutter SDK](https://supabase.com/docs/guides/realtime/quickstarts/flutter)
- [Flutter Performance](https://flutter.dev/perf)
- [Dart Effective Dart](https://dart.dev/guides/language/effective-dart)

---

## FAQ

**Q: How do I add a new datasource (e.g., REST API)?**  
A: Create a new datasource class in `data/datasources/`, implement the interface in the repository.

**Q: When should I use Isar vs. Riverpod cache?**  
A: Isar for persistent offline data; Riverpod for session state (lost on app restart).

**Q: Can I use BLoC instead of Riverpod?**  
A: Not recommended; BLoC adds boilerplate. Riverpod is simpler for this project.

**Q: How do I handle real-time updates?**  
A: Use Riverpod's `StreamProvider` with Supabase realtime subscriptions.

---

**End of CLAUDE.md**
