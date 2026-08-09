import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum KumoMapProvider { openStreetMap, googleMaps }

final mapProviderConfigProvider =
    StateNotifierProvider<MapProviderNotifier, KumoMapProvider>(
      (_) => MapProviderNotifier(),
    );

class MapProviderNotifier extends StateNotifier<KumoMapProvider> {
  MapProviderNotifier() : super(KumoMapProvider.openStreetMap) {
    _loadSaved();
  }

  static const _prefKey = 'kumo_map_provider';

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == null) {
      return;
    }
    final found = KumoMapProvider.values
        .where((p) => p.name == saved)
        .firstOrNull;
    if (found != null && found != state) {
      state = found;
    }
  }

  Future<void> setProvider(KumoMapProvider provider) async {
    state = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, provider.name);
  }
}
