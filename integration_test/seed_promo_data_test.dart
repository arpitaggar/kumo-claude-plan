// One-shot seed script for integration_test/promo_screenshots_test.dart —
// creates a real-looking demo trip ("Kyoto Autumn Escape", must match that
// file's `_tripTitle` exactly) on the dedicated test account: itinerary
// items, a route segment, and a few chat messages. Not a regression test —
// re-running it just adds duplicate items/messages to the same trip, so run
// it exactly once per fresh test account (or manually delete the trip from
// Home first if re-seeding).
//
// Run with:
//   flutter test integration_test/seed_promo_data_test.dart -d <device> \
//     --dart-define-from-file=env.local.json \
//     --dart-define-from-file=integration_test/test_account.json
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumo_claude/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');

/// Must match promo_screenshots_test.dart's `_tripTitle` exactly.
const _tripTitle = 'Kyoto Autumn Escape';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTicks = 80,
  Duration tick = const Duration(milliseconds: 250),
}) async {
  for (var i = 0; i < maxTicks; i++) {
    // A `.first`-filtered finder (e.g. `find.text('Add').first`) throws
    // `Bad state: No element` from `evaluate()` itself when there are zero
    // matches, rather than returning an empty result like a plain finder
    // does — treat that as "not found yet" too, since every call site here
    // may be passed either kind.
    try {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    } catch (_) {
      // not found yet
    }
    await tester.pump(tick);
  }
}

/// Waits for [finder] and taps it, retrying if the tap itself throws — the
/// itinerary detail page rebuilds from a live Realtime stream, so a widget
/// located by `evaluate()` can go defunct in the real gap between that call
/// and `WidgetController.tap()`'s own internal geometry/View lookup (this is
/// `integration_test` driving a real engine with real async scheduling, not
/// `flutter test`'s fake clock — a rebuild can land in that gap without an
/// explicit pump). Confirmed empirically: identical taps failed with `Bad
/// state: No element` at different points across otherwise-identical runs.
Future<void> _tapStable(
  WidgetTester tester,
  Finder Function() build, {
  int retries = 6,
}) async {
  for (var attempt = 0; attempt < retries; attempt++) {
    await _pumpUntilFound(tester, build());
    try {
      await tester.tap(build());
      return;
    } catch (_) {
      if (attempt == retries - 1) {
        rethrow;
      }
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
}

/// Confirms a date-then-time picker pair with their pre-filled initial
/// values — two sequential native dialogs, each closed with "OK". No need
/// to pick a specific day/time for demo data, just move past both dialogs.
Future<void> _acceptDateTime(WidgetTester tester, {required String label}) async {
  await _tapStable(
    tester,
    () => find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    ).first,
  );
  await _pumpUntilFound(tester, find.text('OK'));
  await tester.tap(find.text('OK'));
  await tester.pump(const Duration(milliseconds: 300));
  await _pumpUntilFound(tester, find.text('OK'));
  await tester.tap(find.text('OK'));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _addItem(
  WidgetTester tester, {
  required String title,
  required String location,
}) async {
  await _tapStable(tester, () => find.text('Add').first);
  await _pumpUntilFound(tester, find.byType(TextFormField));
  await tester.pump(const Duration(milliseconds: 300));

  await tester.enterText(find.byType(TextFormField).at(0), title);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();

  await _acceptDateTime(tester, label: 'Start');

  await tester.enterText(find.byType(TextFormField).at(1), location);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();

  await tester.tap(find.text('Add Activity'));
  // Submission inserts + navigates back to the trip detail page.
  await _pumpUntilFound(tester, find.text('Add'), maxTicks: 100);
}

/// Types into the location search sheet's Search tab and taps the first
/// result — a real Nominatim network call, so this waits generously.
Future<void> _pickSearchLocation(WidgetTester tester, String query) async {
  await _pumpUntilFound(tester, find.byType(TextField));
  await tester.enterText(find.byType(TextField).first, query);
  // Debounce (500ms) + real network round-trip.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await _pumpUntilFound(tester, find.byType(ListTile), maxTicks: 60);
  await _tapStable(tester, () => find.byType(ListTile).first);
}

Future<void> _sendChatMessage(WidgetTester tester, String content) async {
  await tester.enterText(find.byType(TextField).first, content);
  await tester.pump(const Duration(milliseconds: 200));
  await _tapStable(tester, () => find.byIcon(Icons.send_rounded));
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed Kyoto Autumn Escape demo trip', (tester) async {
    expect(
      _testEmail,
      isNotEmpty,
      reason:
          'Run with --dart-define-from-file=integration_test/test_account.json.',
    );

    await const FlutterSecureStorage().delete(key: 'supabase.session');
    // Same pre-seed as promo_screenshots_test.dart — avoids the native
    // "'Kumo' Would Like to Send You Notifications" dialog absorbing taps.
    await (await SharedPreferences.getInstance()).setBool(
      'notif_permission_requested',
      true,
    );

    await app.main();
    for (var i = 0; i < 120; i++) {
      if (find.text('Profile').evaluate().isNotEmpty) {
        break;
      }
      if (find.text('Skip').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
        await tester.pump(const Duration(milliseconds: 500));
        continue;
      }
      if (find.text('Sign In').evaluate().isNotEmpty &&
          find.byType(TextFormField).evaluate().length >= 2) {
        await tester.enterText(find.byType(TextFormField).at(0), _testEmail);
        await tester.enterText(
          find.byType(TextFormField).at(1),
          _testPassword,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.text('Sign In'));
        await tester.pump(const Duration(milliseconds: 500));
        continue;
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Profile'), findsOneWidget);

    // --- Create the trip ---
    // Home's own trip-list fetch is still in flight right after the shell
    // mounts (bottom nav renders before itineraryListProvider resolves), so
    // wait for whichever entry point actually appears rather than checking
    // once immediately.
    Finder newTripEntry() => find.text('+ New').evaluate().isNotEmpty
        ? find.text('+ New')
        : find.text('Plan a Trip');
    await _tapStable(tester, newTripEntry);
    await _pumpUntilFound(tester, find.byType(TextFormField));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byType(TextFormField).at(0),
      _tripTitle,
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Ten days chasing maple leaves through temples, bamboo groves, and '
      'back-alley ramen shops.',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '2400');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    for (final label in ['Start', 'End']) {
      await tester.tap(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
      );
      await _pumpUntilFound(tester, find.text('OK'));
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.tap(find.text('Create Trip'));
    await _pumpUntilFound(tester, find.text(_tripTitle), maxTicks: 80);

    // --- Open the trip ---
    await _tapStable(tester, () => find.text(_tripTitle));
    await _pumpUntilFound(tester, find.text('Route'));

    // --- Itinerary tab: add activities ---
    await _addItem(
      tester,
      title: 'Fushimi Inari Taisha',
      location: 'Fushimi Inari, Kyoto',
    );
    await _addItem(
      tester,
      title: 'Kinkaku-ji (Golden Pavilion)',
      location: 'Kinkaku-ji, Kyoto',
    );
    await _addItem(
      tester,
      title: 'Arashiyama Bamboo Grove',
      location: 'Arashiyama, Kyoto',
    );
    await _addItem(
      tester,
      title: 'Kaiseki Dinner in Gion',
      location: 'Gion, Kyoto',
    );

    // --- Route tab: add one segment ---
    await _tapStable(tester, () => find.text('Route').first);
    await _tapStable(tester, () => find.text('Add').first);
    await _pumpUntilFound(tester, find.text('Origin'));

    await _tapStable(
      tester,
      () => find.ancestor(
        of: find.text('Origin'),
        matching: find.byType(InkWell),
      ).first,
    );
    await _pickSearchLocation(tester, 'Tokyo Station');

    await _tapStable(
      tester,
      () => find.ancestor(
        of: find.text('Destination'),
        matching: find.byType(InkWell),
      ).first,
    );
    await _pickSearchLocation(tester, 'Kyoto Station');

    await _tapStable(tester, () => find.text('Add Segment'));
    await _pumpUntilFound(tester, find.text('Route'), maxTicks: 80);

    // --- Trip chat: a few messages ---
    await _tapStable(tester, () => find.byTooltip('Trip chat'));
    await _pumpUntilFound(tester, find.byType(TextField));
    await _sendChatMessage(
      tester,
      "Can't wait for this trip! Just booked my flights \u{1F341}",
    );
    await _sendChatMessage(
      tester,
      'Found a great spot for kaiseki dinner in Gion, added it to the '
      'itinerary',
    );
    await _sendChatMessage(tester, 'Perfect, see you all at Kyoto Station!');
    await tester.pump(const Duration(seconds: 1));
  });
}
