// Captures a set of clean, real-app screenshots on a real device/simulator
// for use in promotional material (App Store screenshots, 2D animation
// videos, marketing decks) — not a pass/fail regression test, though it's
// still written as one so a broken navigation path fails loudly instead of
// silently producing an empty screenshot set.
//
// Requires demo data seeded first — a real trip named `_tripTitle` with
// items, route segments, and chat messages on the dedicated test account;
// the SMOKETEST- prefix convention every other integration test here uses
// is deliberately NOT used for this trip, since the whole point is for it
// to look like a real trip in a screenshot, not test fixture data.
//
// Screenshots are captured via IntegrationTestWidgetsFlutterBinding's
// takeScreenshot() (returns raw PNG bytes directly in Dart) and printed to
// stdout as base64, chunked, between SCREENSHOT_BEGIN:<name> /
// SCREENSHOT_END:<name> markers — NOT written to on-device storage.
// On-device storage was the first approach here and it doesn't work: the
// app's data container (and everything in it) can vanish before a host
// script gets a chance to pull it — `flutter test` tears the app down
// aggressively after (and, empirically, sometimes seemingly during) a run,
// and a real run confirmed a file this test itself had just finished
// writing was already gone by the time a `cp` reached it a moment later.
// The host's captured stdout log, by contrast, is a plain file that
// outlives the simulator process entirely, so routing the actual pixel
// data through it sidesteps the whole container-lifetime problem. See the
// companion `scripts/extract_promo_screenshots.py` (or equivalent) for the
// host-side decode step.
//
// Run with:
//   flutter test integration_test/promo_screenshots_test.dart -d <device> \
//     --dart-define-from-file=env.local.json \
//     --dart-define-from-file=integration_test/test_account.json \
//     > promo_run.log 2>&1
// then decode with:
//   python3 scripts/extract_promo_screenshots.py promo_run.log <output-dir>
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumo_claude/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');

/// Must match the title the seed script created — deliberately a real-
/// sounding name, not a SMOKETEST- prefixed fixture (see this file's
/// header comment for why).
const _tripTitle = 'Kyoto Autumn Escape';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTicks = 240,
  Duration tick = const Duration(milliseconds: 250),
}) async {
  for (var i = 0; i < maxTicks; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(tick);
  }
}

/// Printed lines this long risk being split/dropped by some part of the
/// flutter test / device-log transport — kept conservative, not tuned to
/// any documented limit (none found for this specific pipe).
const _chunkSize = 2000;

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name, {
  // False for transient screens (splash, login) that a settle wait would
  // just pump straight past — those need capturing on the very next frame,
  // not after several seconds of waiting for network/animation to finish.
  bool settle = true,
}) async {
  if (settle) {
    // Best-effort settle beyond pumpAndSettle's own wait — map tiles/route
    // geometry fetches are real network calls with no pump-visible "done"
    // signal, so a fixed pause is the only practical way to give them a
    // chance to render before the shot; a screenshot mid-tile-load is a
    // cosmetic miss, not a test failure, so this isn't gated on a stricter
    // check.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }
  final bytes = await binding.takeScreenshot(name);
  final b64 = base64Encode(bytes);
  // ignore: avoid_print
  print('SCREENSHOT_BEGIN:$name');
  for (var i = 0; i < b64.length; i += _chunkSize) {
    final end = i + _chunkSize < b64.length ? i + _chunkSize : b64.length;
    // ignore: avoid_print
    print('SCREENSHOT_CHUNK:${b64.substring(i, end)}');
  }
  // ignore: avoid_print
  print('SCREENSHOT_END:$name');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture promotional screenshots', (tester) async {
    expect(
      _testEmail,
      isNotEmpty,
      reason:
          'Run with --dart-define-from-file=integration_test/test_account.json.',
    );

    await const FlutterSecureStorage().delete(key: 'supabase.session');

    // Pre-seeds NotificationService's "already asked" flag so
    // kumo_shell.dart's post-login requestPermissionOnce() call never
    // fires the real native "'Kumo' Would Like to Send You Notifications"
    // permission dialog. That dialog is a genuine, previously-undiagnosed
    // blocker for any integration test that runs long enough to reach the
    // authenticated shell: it's a native UIKit/system alert with no
    // Flutter widget-tree presence at all, so every tap after it appears
    // gets silently absorbed instead of reaching the app — confirmed via a
    // live screenshot mid-failure (docs/Checklist.md, 2026-08-17), not
    // guessed. A fresh install always resets this SharedPreferences flag,
    // so it fires on essentially every test run long enough to log in and
    // reach the shell, unless pre-seeded like this.
    await (await SharedPreferences.getInstance()).setBool(
      'notif_permission_requested',
      true,
    );

    await app.main();

    // Android only (no-op on iOS) — must be called once before any
    // takeScreenshot() call on that platform. Done before the very first
    // capture (splash) rather than after login, so every shot in this run
    // is covered, not just the ones after the login loop.
    await binding.convertFlutterSurfaceToImage();

    // --- 0. Splash / initial load ---
    // SplashPage (lib/features/splash/presentation/pages/splash_page.dart)
    // fades in its title/logo/tagline from opacity 0 over a 1600ms
    // AnimationController, then navigates to /login 350ms after that
    // finishes — a single immediate pump (the first thing tried here)
    // caught frame zero, before anything had faded in at all, producing a
    // blank screenshot. Pump to roughly 1500ms into the timeline instead —
    // late enough for the logo/tagline (which finish fading in at 65%/85%
    // of the 1600ms duration) to be fully visible, comfortably before the
    // ~1950ms mark where it navigates away.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await _capture(binding, tester, '00_splash', settle: false);

    // --- If a stale session got auto-restored, force a real sign-out ---
    // Deleting the 'supabase.session' secure-storage key (above) is what
    // authenticated_flows_test.dart relies on for a fresh login every run,
    // but a real run of this file landed straight on the authenticated
    // shell without ever showing the login form at all — no explanation
    // found for why that key alone didn't prevent it (not guessed away:
    // confirmed via a live run where 'Sign In' never appeared in the log at
    // all before 'Profile' did). Rather than chase the exact storage-key
    // mechanism further, force correctness structurally: if we land on the
    // shell without ever seeing the login form, explicitly sign out through
    // the real UI and log back in as the known test account, so every run
    // ends up authenticated as `_testEmail` regardless of what was
    // restored.
    var reachedShellWithoutLogin = false;
    for (var i = 0; i < 120; i++) {
      if (find.text('Profile').evaluate().isNotEmpty) {
        reachedShellWithoutLogin = true;
        break;
      }
      if (find.text('Skip').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
        await tester.pump(const Duration(milliseconds: 500));
        continue;
      }
      if (find.text('Sign In').evaluate().isNotEmpty &&
          find.byType(TextFormField).evaluate().length >= 2) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 250));
    }

    if (reachedShellWithoutLogin) {
      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 500));
      // Mirrors authenticated_flows_test.dart's own Sign Out scroll — the
      // "New Badge Unlocked!" celebration dialog can cover the screen and
      // absorb every drag below if still up, and Profile's ListView can be
      // long enough that Sign Out is outside the lazily-built viewport.
      for (var i = 0; i < 15; i++) {
        if (find.text('Sign Out').evaluate().isNotEmpty) {
          break;
        }
        if (find.text('Nice!').evaluate().isNotEmpty) {
          await tester.tap(find.text('Nice!'));
          await tester.pump(const Duration(milliseconds: 500));
          continue;
        }
        await tester.dragFrom(const Offset(200, 400), const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text('Sign Out'));
      await _pumpUntilFound(tester, find.text('Sign In'), maxTicks: 40);
    }

    var loginCaptured = false;
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
        // --- 1. Login screen ---
        // Captured once, before filling it in, on this dedicated test
        // account's own login screen (no real personal data on it).
        if (!loginCaptured) {
          await _capture(binding, tester, '01_login', settle: false);
          loginCaptured = true;
        }
        await tester.enterText(find.byType(TextFormField).at(0), _testEmail);
        await tester.enterText(find.byType(TextFormField).at(1), _testPassword);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.text('Sign In'));
        await tester.pump(const Duration(milliseconds: 500));
        continue;
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Profile'), findsOneWidget);

    // --- Ensure Work Mode is off before anything else ---
    // Work Mode is persisted locally (SharedPreferences), not reset between
    // separate `flutter test` runs on the same simulator/device — a prior
    // interrupted run (this device has had several today) can leave it on.
    // With Work Mode active, Home only shows org-tagged trips
    // (visibleItinerariesProvider filters on orgId), and the demo trip is
    // untagged (Personal) — so a stuck-on Work Mode reproduces exactly the
    // "No trips yet" empty state, which looks identical to the *documented*
    // itineraryListProvider session-restore race but has a completely
    // different cause. Confirmed directly (not guessed): a REST query
    // against the live DB with this same account showed the trip present,
    // owned by this account, org_id null — so a fetch race was ruled out
    // before this check was added.
    Switch? workModeSwitch;
    for (var i = 0; i < 24; i++) {
      final matches = find.byType(Switch).evaluate();
      if (matches.length == 1) {
        workModeSwitch = matches.single.widget as Switch;
        break;
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (workModeSwitch != null && workModeSwitch.value) {
      await tester.tap(find.byType(Switch));
      await _pumpUntilFound(tester, find.text('Personal'), maxTicks: 40);
    }

    // --- 2. Home (trips list) ---
    // itineraryListProvider's first fetch is triggered by HomePage's own
    // initState() postFrameCallback — i.e. essentially the instant Home
    // builds, right after the login redirect, which can race
    // KumoSupabaseClient's session attachment (the same class of bug
    // documented for myOrganizationsProvider in
    // authenticated_flows_test.dart and fixed the same way for
    // fcmTokenSyncProvider in notification_providers.dart). Unlike those
    // two, there's no useful place to put a "wait before the first read"
    // delay here — the first read isn't something this test's own code
    // triggers, it's implicit in navigating to Home at all, which already
    // happened by the time this line runs. Confirmed via a real captured
    // screenshot showing the account correctly authenticated but "No trips
    // yet" (docs/Checklist.md, 2026-08-17), not guessed.
    //
    // Fix: force a genuine re-fetch through the app's own existing
    // softRefresh-after-create-trip behavior (home_page.dart's empty-state
    // _EmptyState.onCreate calls softRefresh() unconditionally once
    // /create-trip's push Future resolves, regardless of whether a trip
    // was actually created) — enter Plan a Trip, immediately back out
    // without creating anything, land back on Home with a fresh fetch made
    // well after the session is definitely attached.
    await _pumpUntilFound(
      tester,
      find.text('Plan a Trip').evaluate().isNotEmpty
          ? find.text('Plan a Trip')
          : find.text(_tripTitle),
    );
    if (find.text(_tripTitle).evaluate().isEmpty) {
      await tester.tap(find.text('Plan a Trip'));
      await _pumpUntilFound(tester, find.byType(TextFormField));
      await tester.pageBack();
      await _pumpUntilFound(tester, find.text(_tripTitle));
    }
    // Unconditional diagnostic shot — saved even if the trip-not-found
    // check below fails, so a failure is debuggable from the file alone
    // instead of needing a live screen check.
    await _capture(binding, tester, '02_home_diagnostic');
    expect(
      find.text(_tripTitle),
      findsOneWidget,
      reason:
          'Demo trip not found — run the seed script first (see this '
          "file's header comment).",
    );
    await _capture(binding, tester, '03_home');

    // --- 4/5/6. The other bottom-nav tabs ---
    await tester.tap(find.text('Trips'));
    await tester.pump(const Duration(milliseconds: 500));
    await _capture(binding, tester, '04_trips_tab');

    await tester.tap(find.text('Inbox'));
    await tester.pump(const Duration(milliseconds: 500));
    await _capture(binding, tester, '05_inbox_tab');

    await tester.tap(find.text('Discover'));
    await tester.pump(const Duration(milliseconds: 500));
    await _capture(binding, tester, '06_discover_tab');

    await tester.tap(find.text('Home'));
    await _pumpUntilFound(tester, find.text(_tripTitle));

    // --- 7. Trip detail — Itinerary tab (default) ---
    await tester.tap(find.text(_tripTitle));
    await _pumpUntilFound(tester, find.text('Route'));
    await _capture(binding, tester, '07_trip_itinerary');

    // --- 7b. Same tab, scrolled down to the Travellers (members) card ---
    // `find.text('Travellers')` can match an Element that exists in the
    // tree but isn't actually painted on screen yet — ListView pre-builds
    // items just past the viewport within its cacheExtent, so checking
    // existence alone to decide "have we scrolled enough" can report true
    // on the very first frame, before any real scrolling happened (a real
    // run produced a screenshot byte-for-byte identical to 07_trip_itinerary
    // this way). Always perform a fixed set of drags first, then just
    // confirm Travellers is there for the capture.
    for (var i = 0; i < 5; i++) {
      await tester.dragFrom(const Offset(200, 600), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await _pumpUntilFound(tester, find.text('Travellers'));
    await _capture(binding, tester, '07b_trip_members');

    // --- 8. Trip detail — Route/Map tab ---
    await tester.tap(find.text('Route'));
    await _capture(binding, tester, '08_trip_route');

    // --- 9. Trip chat ---
    await tester.tap(find.byTooltip('Trip chat'));
    await _pumpUntilFound(tester, find.byType(TextField));
    await _capture(binding, tester, '09_trip_chat');

    // Pop back to the shell (bottom nav) — `/trip/:id` and its chat/segment
    // /item sub-routes sit outside the ShellRoute in router.dart, so one
    // pageBack() only leaves chat for the trip detail page, not all the way
    // to the shell; a second is needed before a bottom-nav tab like
    // 'Profile' even exists to tap. Loop-and-check on the shell's actual
    // `NavigationBar` widget (not the trip title text, which a still-
    // mounted underlying route could also match) rather than hard-coding
    // exactly two pops, since a real run showed a rigid two-pop count alone
    // wasn't reliable here.
    for (var i = 0; i < 4; i++) {
      if (find.byType(NavigationBar).evaluate().isNotEmpty) {
        break;
      }
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await _pumpUntilFound(tester, find.text('Profile'));

    // --- 10. Profile ---
    // Waits on 'Edit Profile' rather than the org-gated 'My Organizations'
    // tile deliberately — the latter depends on myOrganizationsProvider,
    // which has a documented session-restore race (see
    // authenticated_flows_test.dart's _ensureWorkMode) unrelated to
    // anything this screenshot tool needs to care about.
    await tester.tap(find.text('Profile'));
    await _pumpUntilFound(tester, find.text('Edit Profile'));
    // A "New Badge Unlocked!" celebration dialog (e.g. "First Steps") can
    // cover the screen on this visit — see authenticated_flows_test.dart's
    // own Sign Out scroll for the same dialog, whose comment notes it "can
    // appear on a delayed pump, not necessarily by the first check" — a
    // single immediate check here missed it in a real run. Poll for a few
    // pumps instead of checking once.
    for (var i = 0; i < 8; i++) {
      if (find.text('Nice!').evaluate().isNotEmpty) {
        await tester.tap(find.text('Nice!'));
        await tester.pump(const Duration(milliseconds: 500));
        break;
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    await _capture(binding, tester, '10_profile');
  });
}
