// Cross-platform coverage for the org join-code flow: one platform's real
// app generates a code as the org admin, a different platform's real app
// redeems it as a fresh member — proving the feature actually works across
// platforms, not just that the backend RPCs (generate_org_join_code /
// redeem_org_join_code) are platform-agnostic, which is true by
// construction (they're plain Supabase REST calls) but doesn't exercise
// either app's real UI.
//
// Like deep_link_test.dart, this can't drive both devices from one Dart
// process — each `flutter test -d <device>` run is a separate app instance
// on a separate platform. So this file has two roles, selected via
// --dart-define=ROLE=generate|redeem, orchestrated by a host-side script
// that runs the "generate" role first, captures the printed code from its
// log, then runs the "redeem" role on the *other* platform with that code
// passed in via --dart-define=JOIN_CODE=... See this file's own generate/
// redeem bodies below for the exact marker/log conventions.
//
// Run (generate role, as the admin account — reuses test_account.json):
//   flutter test integration_test/cross_platform_join_test.dart -d <device> \
//     --dart-define=ROLE=generate \
//     --dart-define-from-file=env.local.json \
//     --dart-define-from-file=integration_test/test_account.json
//
// Run (redeem role, as a fresh redeemer account — never the admin account,
// which is already a member and would hit "already a member" instead of
// actually testing redemption):
//   flutter test integration_test/cross_platform_join_test.dart -d <device> \
//     --dart-define=ROLE=redeem \
//     --dart-define=JOIN_CODE=<code captured from the generate run> \
//     --dart-define-from-file=env.local.json \
//     --dart-define=TEST_EMAIL=<redeemer email> \
//     --dart-define=TEST_PASSWORD=<redeemer password> \
//     --dart-define=TEST_ORG_NAME=<org name, e.g. "Kumo Smoketest Org">
//
// The redeem role's own deep-link firing (a host-side `xcrun simctl
// openurl` / `adb shell am start`) is external to this file for the same
// reason deep_link_test.dart's is — a sandboxed on-device Dart isolate has
// no shell access to invoke either.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumo_claude/main.dart' as app;

const _role = String.fromEnvironment('ROLE');
const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');
const _testOrgName = String.fromEnvironment('TEST_ORG_NAME');
const _joinCode = String.fromEnvironment('JOIN_CODE');

/// Printed once this run has logged in and reached the ready point for its
/// role — a host-side script greps for this before doing its own
/// off-device half of the work (reading the generated code, or firing the
/// deep link). Kept identical in shape to deep_link_test.dart's own marker
/// convention.
const _readyMarker = 'SMOKETEST_XPLAT_READY';

/// The host-side script greps for this exact prefix to capture the
/// generated code out of the generate role's log output.
const _codeMarkerPrefix = 'SMOKETEST_XPLAT_JOIN_CODE:';

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

/// Shared login flow — same "advance whichever applies" loop as
/// authenticated_flows_test.dart and deep_link_test.dart, since a prior
/// interrupted run can leave the app on login/onboarding/already-restored.
Future<void> _login(WidgetTester tester) async {
  await const FlutterSecureStorage().delete(key: 'supabase.session');
  await app.main();
  for (var i = 0; i < 120; i++) {
    if (find.text('Profile').evaluate().isNotEmpty) {
      return;
    }
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 500));
      continue;
    }
    if (find.text('Sign In').evaluate().isNotEmpty &&
        find.byType(TextFormField).evaluate().length >= 2) {
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
  fail('Never reached the authenticated shell (Profile tab) — see the '
      'login loop above for every state this run tried to advance past.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cross-platform org join-code flow (role-driven)', (
    tester,
  ) async {
    expect(
      _role == 'generate' || _role == 'redeem',
      isTrue,
      reason: 'Run with --dart-define=ROLE=generate or ROLE=redeem — see '
          'this file\'s header comment for the full two-sided procedure.',
    );
    expect(
      _testEmail,
      isNotEmpty,
      reason: 'Missing --dart-define=TEST_EMAIL / TEST_PASSWORD.',
    );

    await _login(tester);

    // Deliberate settle delay *before* the first thing that reads
    // myOrganizationsProvider (tapping into Profile, below) — not after,
    // which authenticated_flows_test.dart's own "KNOWN BUG" comment on
    // this exact provider documents as useless once the race has already
    // hit ("independent of how long you wait afterward"). A plain
    // FutureProvider never retries once it's resolved, so what actually
    // matters is giving KumoSupabaseClient's session attachment enough of
    // a head start that it's already done by the time anything reads this
    // provider for the first time, not padding time after that read.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    if (_role == 'generate') {
      expect(
        _testOrgName,
        isNotEmpty,
        reason: 'Missing --dart-define-from-file=integration_test/'
            'test_account.json (needed for TEST_ORG_NAME).',
      );

      // Profile -> My Organizations -> the org -> Join codes -> generate.
      // find.text('Profile') in _login() above only confirms the bottom
      // nav (shell chrome) is showing — it's a landmark, not proof
      // ProfilePage itself is the active tab (the shell can default to
      // Home). Must actually tap it, same as
      // authenticated_flows_test.dart does before its own "Sign Out"
      // reach — missing this tap looks exactly like the documented
      // myOrganizationsProvider session-restore race (a blank scroll
      // finding nothing) but isn't; confirmed by checking this account's
      // org membership directly against the database mid-debugging.
      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 500));

      // "My Organizations" sits below several other tiles (and a
      // celebration dialog can cover the screen after this account's
      // first-ever badge) — same scroll-loop shape as
      // authenticated_flows_test.dart's "Sign Out" reach, not a
      // single-shot drag, since exactly how far to scroll depends on
      // device height.
      for (var i = 0; i < 15; i++) {
        if (find.text('My Organizations').evaluate().isNotEmpty) {
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
      expect(
        find.text('My Organizations'),
        findsOneWidget,
        reason: 'The admin account (test_account.json) should always have '
            '≥1 org, making this tile visible on Profile.',
      );
      await tester.tap(find.text('My Organizations'));
      await _pumpUntilFound(tester, find.text(_testOrgName));
      await tester.tap(find.text(_testOrgName));
      await _pumpUntilFound(tester, find.byTooltip('Join codes'));
      await tester.tap(find.byTooltip('Join codes'));
      await _pumpUntilFound(tester, find.byTooltip('Generate code'));
      await tester.tap(find.byTooltip('Generate code'));

      // Every dialog field is left at its default (role: Member, expires:
      // 7 days, uses: 1) — a single-use code is exactly what this test
      // needs, and exercising the dropdowns isn't this test's job (that's
      // org_join_codes_page_test.dart's).
      await _pumpUntilFound(tester, find.text('Generate join code'));
      await tester.tap(find.text('Generate'));

      await _pumpUntilFound(tester, find.byType(SelectableText));
      final codeWidget =
          find.byType(SelectableText).evaluate().single.widget
              as SelectableText;
      final code = codeWidget.data!;
      expect(code, isNotEmpty);

      // ignore: avoid_print
      print('$_codeMarkerPrefix$code');
      // ignore: avoid_print
      print(_readyMarker);

      // No further action needed from this side — the code is already
      // live in the database the moment generate_org_join_code returns,
      // well before this print. Leaving the "Join code" dialog open (not
      // tapping Done / navigating away) is deliberate: nothing about
      // redemption depends on this app's own navigation state, and
      // closing it just adds steps with no test value.
      return;
    }

    // ROLE == 'redeem'.
    expect(
      _joinCode,
      isNotEmpty,
      reason: 'Missing --dart-define=JOIN_CODE=<code from the generate '
          'run\'s SMOKETEST_XPLAT_JOIN_CODE: log line>.',
    );

    // ignore: avoid_print
    print(_readyMarker);

    // The host-side script fires the real kumo://join?joinCode=... OS-level
    // link sometime after seeing the marker above (same two-sided
    // convention as deep_link_test.dart).
    await _pumpUntilFound(tester, find.text('Join organization'));
    expect(
      find.text('Join organization'),
      findsOneWidget,
      reason: 'The deep link should have landed on Join Organization by '
          'now — see deep_link_test.dart for what to check if this fails '
          '(host script timing, platform manifest registration, '
          'router.dart\'s joinCode parsing).',
    );

    final codeField = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == _joinCode,
    );
    expect(
      codeField,
      findsOneWidget,
      reason: 'The join-code field should be pre-filled with the exact '
          'code the generate role produced.',
    );

    await tester.tap(find.text('Join'));

    // A real network round-trip (redeem_org_join_code), so poll rather
    // than a fixed delay.
    await _pumpUntilFound(tester, find.text('Members'));
    expect(
      find.text('Members'),
      findsOneWidget,
      reason: 'A successful redemption navigates to the org\'s Members '
          'page (JoinOrganizationPage._redeem) — this is the actual '
          'cross-platform assertion: the code generated by one platform\'s '
          'app was accepted by a different platform\'s app.',
    );
  });
}
