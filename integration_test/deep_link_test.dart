// Fires the real `kumo://join?joinCode=XYZ` OS-level deep link at a running
// app instance and confirms it lands on Join Organization pre-filled — the
// gap flagged in docs/Checklist.md's "Join-code deep link" entry: the
// native AndroidManifest.xml/Info.plist scheme registration and
// router.dart's `state.uri.host`-vs-`.path` handling had never been
// exercised against a real simulator/emulator, only reasoned about.
//
// This test is also the regression guard for a real bug this exact smoke
// test found on first run (2026-08-17): the query param used to be named
// `code`, which collides with supabase_flutter's own PKCE deep-link
// listener (`SupabaseAuth._isAuthCallbackDeeplink` treats ANY incoming URI
// with a `code` query param as an auth callback, regardless of host) — the
// link was silently swallowed before ever reaching router.dart's
// redirect(). See router.dart's own comment on the `joinCode` rename for
// the full mechanism.
//
// Unlike authenticated_flows_test.dart, this test cannot fire the link
// itself: a custom-URL-scheme open is an OS-level action (`xcrun simctl
// openurl` / `adb shell am start`), and a Dart integration test runs
// sandboxed *inside* the app process on the target device — it has no
// shell access to invoke either. So this test only handles its own half
// (log in, then wait); a host-side script fires the real link mid-run once
// it sees this test print the ready marker below. See this directory's
// README for the exact two-sided run procedure.
//
// The deep-linked code itself is a fixed, non-existent placeholder
// (`SMOKETEST-DEEPLINK-CODE`) — this test only exercises the redirect
// plumbing (does the OS deliver the URI, does router.dart parse it and land
// on the right route with the code pre-filled), not the redemption RPC
// itself, which already has its own coverage
// (redeem_org_join_code_usecase_test.dart, organization_repository_impl_test.dart)
// plus a separate live-database concurrency pass (see docs/Checklist.md).
// The test deliberately never taps "Join", so it makes zero backend writes.
//
// Run with:
//   flutter test integration_test/deep_link_test.dart -d <device> \
//     --dart-define-from-file=env.local.json \
//     --dart-define-from-file=integration_test/test_account.json
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumo_claude/main.dart' as app;

const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');

/// The exact marker a host-side script greps for in this test's log output
/// to know it's safe to fire the OS-level deep link now. Must stay in sync
/// with integration_test/README.md's documented run procedure.
const deepLinkReadyMarker = 'SMOKETEST_DEEP_LINK_READY';

/// The placeholder code this test expects to see pre-filled after the
/// deep link redirects to Join Organization. Must stay in sync with the
/// `kumo://join?code=...` URL the host-side script actually fires.
const deepLinkTestCode = 'SMOKETEST-DEEPLINK-CODE';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTicks = 60,
  Duration tick = const Duration(milliseconds: 250),
}) async {
  for (var i = 0; i < maxTicks; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(tick);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kumo://join?code=XYZ deep link opens Join Organization '
      'pre-filled', (tester) async {
    expect(
      _testEmail,
      isNotEmpty,
      reason:
          'Run with --dart-define-from-file=integration_test/test_account.json '
          '(see this file\'s header comment for the full command).',
    );

    // Same rationale as authenticated_flows_test.dart: force a genuine
    // fresh login every run rather than trusting whatever session survived
    // in the Keychain/secure storage from a prior interrupted run.
    await const FlutterSecureStorage().delete(key: 'supabase.session');
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
        await tester.enterText(find.byType(TextFormField).at(1), _testPassword);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.text('Sign In'));
        await tester.pump(const Duration(milliseconds: 500));
        continue;
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      find.text('Profile'),
      findsOneWidget,
      reason: 'Should be in the authenticated shell before the deep link '
          'can be tested — router.dart only handles kumo://join when '
          'already signed in.',
    );

    // ignore: avoid_print
    print(deepLinkReadyMarker);

    // The host-side script fires `xcrun simctl openurl` / `adb shell am
    // start` sometime after seeing the marker above. Poll rather than a
    // fixed delay, since exactly how long that takes depends on host
    // process scheduling, not this app.
    await _pumpUntilFound(
      tester,
      find.text('Join organization'),
      maxTicks: 1200, // up to 5 minutes — the host-side script firing the
      // link is a separate manual/orchestrated step (see this file's
      // header comment), not bounded by anything this test controls.
    );
    expect(
      find.text('Join organization'),
      findsOneWidget,
      reason: 'The real kumo://join?code=... OS-level link should have '
          'landed on Join Organization by now. If this fails, check: (1) '
          'the host script actually fired the link, (2) the app was '
          'foregrounded/backgrounded correctly for the platform, (3) '
          'AndroidManifest.xml/Info.plist scheme registration, (4) '
          'router.dart\'s state.uri.host/.path handling.',
    );

    final codeField = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == deepLinkTestCode,
    );
    expect(
      codeField,
      findsOneWidget,
      reason: 'The join-code field should be pre-filled with the code from '
          'the deep link URL, confirming router.dart actually parsed the '
          'query parameter rather than just landing on the right route.',
    );

    // No further cleanup needed: this test never tapped "Join" (the code
    // doesn't exist server-side — deliberately, so this test makes zero
    // backend writes), and the next run force-deletes the secure-storage
    // session before logging in again (above) regardless of which screen
    // this run ends on. A deep-link navigation via GoRouter's redirect()
    // replaces the stack rather than pushing, so there's no reliable
    // "back to Profile" screen to pop to here the way
    // authenticated_flows_test.dart's ordinary in-app navigation has.
  });
}
