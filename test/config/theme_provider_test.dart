import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/config/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to deepVoyage with no stored preference', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = ThemeNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, KumoTheme.deepVoyage);
  });

  test('loads a previously-saved theme on construction', () async {
    SharedPreferences.setMockInitialValues({
      'kumo_theme': KumoTheme.sunsetCoral.name,
    });
    final notifier = ThemeNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, KumoTheme.sunsetCoral);
  });

  test('falls back to the default for an unrecognised stored value', () async {
    SharedPreferences.setMockInitialValues({'kumo_theme': 'not_a_real_theme'});
    final notifier = ThemeNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, KumoTheme.deepVoyage);
  });

  test('setTheme updates state and persists the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = ThemeNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    await notifier.setTheme(KumoTheme.cloudSilver);

    expect(notifier.state, KumoTheme.cloudSilver);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kumo_theme'), KumoTheme.cloudSilver.name);
  });

  test('toggle cycles to the next value and wraps around at the end', () async {
    SharedPreferences.setMockInitialValues({
      'kumo_theme': KumoTheme.values.last.name,
    });
    final notifier = ThemeNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, KumoTheme.values.last);

    notifier.toggle();
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, KumoTheme.values.first);
  });
}
