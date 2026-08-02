import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
