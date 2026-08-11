import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/maps/kumo_map_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to openStreetMap with no stored preference', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = MapProviderNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, KumoMapProvider.openStreetMap);
  });

  test('loads a previously-saved provider on construction', () async {
    SharedPreferences.setMockInitialValues({
      'kumo_map_provider': KumoMapProvider.googleMaps.name,
    });
    final notifier = MapProviderNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, KumoMapProvider.googleMaps);
  });

  test('falls back to the default for an unrecognised stored value', () async {
    SharedPreferences.setMockInitialValues({
      'kumo_map_provider': 'not_a_real_provider',
    });
    final notifier = MapProviderNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, KumoMapProvider.openStreetMap);
  });

  test('setProvider updates state and persists the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = MapProviderNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    await notifier.setProvider(KumoMapProvider.googleMaps);

    expect(notifier.state, KumoMapProvider.googleMaps);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('kumo_map_provider'),
      KumoMapProvider.googleMaps.name,
    );
  });
}
