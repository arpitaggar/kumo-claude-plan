# lib/config

Migrated from the project root CLAUDE.md (2026-08-03 doctor cleanup) — loads only when working under lib/config/.

### Theming System

Kumo supports ten visual themes: **Cherry Blossom**, **Golden Hour**, **Deep Voyage** (default), **Synthwave Tokyo**, **White & Charcoal**, **Warm Oat & Light Blue** (added in Stage 19), **Sunset Coral**, **Dawn Flight**, **Verdigris Bronze**, and **Cloud Silver** (added in Stage 20).

- **Enum & provider:** `lib/config/theme_provider.dart` — `KumoTheme` enum + `ThemeNotifier extends StateNotifier<KumoTheme>`
- **Persistence:** SharedPreferences key `kumo_theme` stores `KumoTheme.name`; loaded in `ThemeNotifier` constructor via `_loadSaved()`
- **UI:** Theme picker is a bottom sheet on the Profile page (`lib/features/shell/profile_page.dart`); opened via `isScrollControlled: true, useSafeArea: true`
- **Launcher icon:** Fixed as Deep Voyage on both platforms. Runtime icon switching via `PackageManager.setComponentEnabledSetting()` was removed because it clears the Android task stack (the app appears to close).
- **Dark themes:** Synthwave Tokyo (`lib/config/theme.dart`, `_synthwaveScheme`) — magenta-purple dusk sky, orange/gold sunset accent — was the app's first `Brightness.dark` theme. **Dawn Flight** (`_dawnFlightScheme`, Stage 20) is the second — a pre-dawn navy sky with a warm sunrise-orange/gold accent. All other eight themes are `Brightness.light`.
- **Stage 19 fix:** the shell bottom nav bar and `OfflineBanner` had Cherry-Blossom colors hardcoded instead of reading from `Theme.of(context)`, which silently broke visuals under every other theme. Fixed to pull from the active `ColorScheme`.
- **Stage 20 additions:** Sunset Coral (warm terracotta-red/peach), Verdigris Bronze (teal-green patina + bronze/rust), and Cloud Silver (cool teal/slate-blue on pale sky) round out the light themes; each pairs with a previously-unused pre-made logo SVG in `assets/icons/` (`kumo_logo_sunset_coral.svg`, `kumo_logo_dawn_flight.svg`, `kumo_logo_verdigris_bronze.svg`, `kumo_logo_cloud_silver.svg`) that existed in the asset tree before this stage but had no matching `KumoTheme` value or `ColorScheme` — several other unused logo variants (`kumo_logo_copper_patina.svg`, `kumo_logo_slate_mono.svg`, `kumo_logo_terracotta_clay.svg`, etc.) remain available for future themes.


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

