import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/work_mode/presentation/providers/work_mode_provider.dart';

enum KumoTheme {
  cherryBlossom,
  goldenHour,
  deepVoyage,
  synthwaveTokyo,
  whiteAndCharcoal,
  warmOatLightBlue,
  sunsetCoral,
  dawnFlight,
  verdigrisBronze,
  cloudSilver,
  // Enforced-only: never user-selectable via the theme picker. Applied
  // automatically whenever Work Mode is active — see effectiveThemeProvider.
  onyxGold,
}

final themeProvider = StateNotifierProvider<ThemeNotifier, KumoTheme>(
  (_) => ThemeNotifier(),
);

class ThemeNotifier extends StateNotifier<KumoTheme> {
  ThemeNotifier() : super(KumoTheme.deepVoyage) {
    _loadSaved();
  }

  static const _prefKey = 'kumo_theme';

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == null) {
      return;
    }
    final found = KumoTheme.values.where((t) => t.name == saved).firstOrNull;
    if (found != null && found != state) {
      state = found;
    }
  }

  Future<void> setTheme(KumoTheme t) async {
    state = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, t.name);
  }

  void toggle() {
    const values = KumoTheme.values;
    setTheme(values[(values.indexOf(state) + 1) % values.length]);
  }
}

/// The theme actually rendered by the app: forced to Onyx & Gold while Work
/// Mode is active, otherwise the user's own persisted [themeProvider] choice.
/// Work Mode never writes to [themeProvider] itself, so switching back to
/// Private Mode always restores the exact prior personal theme.
final effectiveThemeProvider = Provider<KumoTheme>((ref) {
  if (ref.watch(isWorkModeActiveProvider)) {
    return KumoTheme.onyxGold;
  }
  return ref.watch(themeProvider);
});
