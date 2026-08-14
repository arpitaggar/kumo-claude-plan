// Authenticated end-to-end coverage against the dedicated test account
// (see integration_test/test_account.json / README.md — never a real
// personal account). Every trip this test creates is prefixed
// `SMOKETEST-` and deleted before the test ends, following the safety
// rules in this directory's README.
//
// Run with:
//   flutter test integration_test/authenticated_flows_test.dart -d macos \
//     --dart-define-from-file=env.local.json \
//     --dart-define-from-file=integration_test/test_account.json
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumo_claude/main.dart' as app;

const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');
const _testOrgName = String.fromEnvironment('TEST_ORG_NAME');

/// Manual pump loop instead of `pumpAndSettle()` — several screens here
/// show an indefinitely-animating `CircularProgressIndicator` while a real
/// Supabase call is in flight, which `pumpAndSettle` treats as "never
/// settles" and throws on. See `app_test.dart`'s splash-screen loop for
/// the same reasoning.
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

/// Checks the Work Mode banner's actual persisted switch state before
/// acting, rather than blindly tapping — a prior interrupted run can leave
/// Work Mode on, and blindly toggling was the direct cause of a real trip
/// getting deleted earlier in this project's history (see
/// scripts/web_smoke_test/README.md's safety section and its own
/// `ensureWorkMode`, which this mirrors). No-ops if already in the
/// requested state. The banner (and its Switch) only renders once the
/// account has ≥1 org, which this test account always does.
Future<void> _ensureWorkMode(
  WidgetTester tester, {
  required bool active,
}) async {
  // isWorkModeAvailableProvider (≥1 org) resolves asynchronously, so the
  // Switch can appear-then-vanish across single pump ticks while that
  // settles — a plain find-then-reuse can read a Switch that's already
  // gone by the next evaluation. Loop until exactly one is stably found
  // and read its value from that same match, not a re-evaluated finder.
  Switch? switchWidget;
  for (var i = 0; i < 24; i++) {
    final matches = find.byType(Switch).evaluate();
    if (matches.length == 1) {
      switchWidget = matches.single.widget as Switch;
      break;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  if (switchWidget == null) {
    // KNOWN BUG, not a flaky wait — see integration_test/README.md's
    // "Known issue" section. myOrganizationsProvider can permanently
    // cache an empty org list if it fires before KumoSupabaseClient's
    // session finishes attaching (a supabase_flutter session-restore
    // race), independent of how long you wait afterward.
    fail(
      'Work Mode switch never appeared — myOrganizationsProvider likely '
      'raced Supabase session attachment (see README "Known issue"), not '
      'a slow fetch. Longer waits do not fix this.',
    );
  }
  if (switchWidget.value == active) {
    return;
  }
  await tester.tap(find.byType(Switch));
  await _pumpUntilFound(
    tester,
    active ? find.textContaining('for $_testOrgName') : find.text('Personal'),
    maxTicks: 40,
  );
}

/// Either the "+ New" app-bar action (trips already present) or the
/// "Plan a Trip" empty-state button (zero trips) — whichever Home is
/// actually showing right now, so this works regardless of leftover state
/// from a prior interrupted run.
Finder _newTripEntryPoint() {
  final plusNew = find.text('+ New');
  return plusNew.evaluate().isNotEmpty ? plusNew : find.text('Plan a Trip');
}

Future<void> _fillAndSubmitTripForm(
  WidgetTester tester, {
  required String title,
}) async {
  // Wait for the form field itself, not just the AppBar title — the title
  // can be present a frame or two before the route's body finishes
  // building/laying out during the push transition.
  await _pumpUntilFound(tester, find.byType(TextFormField));
  await tester.pump(const Duration(milliseconds: 300));

  await tester.enterText(find.byType(TextFormField).at(0), title);
  await tester.enterText(find.byType(TextFormField).at(2), '500');
  // On a real device (unlike widget tests) enterText focuses the field and
  // pulls up the real on-screen keyboard, which can then obscure/hit-test
  // -block whatever's tapped next — dismiss it before continuing.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();

  // Accept the date pickers' pre-filled initial dates (today / +7 days) —
  // no need to pick a specific day, just confirm each dialog.
  for (final label in ['Start', 'End']) {
    await tester.tap(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
    );
    await _pumpUntilFound(tester, find.text('OK'));
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  await tester.tap(find.text('Create Trip'));
  // Submission triggers a real insert + navigates back to Home on success.
  await _pumpUntilFound(tester, _newTripEntryPoint(), maxTicks: 80);
}

Future<void> _deleteTrip(WidgetTester tester, String title) async {
  await _pumpUntilFound(tester, find.text(title));
  await tester.tap(
    find.descendant(
      of: find
          .ancestor(of: find.text(title), matching: find.byType(Material))
          .first,
      matching: find.byIcon(Icons.delete_outline),
    ),
  );
  await _pumpUntilFound(tester, find.text('Delete trip?'));
  await tester.tap(find.text('Delete'));
  await _pumpUntilFound(
    tester,
    find.text(title).evaluate().isEmpty ? find.text('Home') : find.text(title),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(
    find.text(title),
    findsNothing,
    reason: 'Trip should be gone from Home after confirming delete',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login, create/delete a Personal trip, toggle Work Mode, '
      'create/delete a Work Mode trip', (tester) async {
    expect(
      _testEmail,
      isNotEmpty,
      reason:
          'Run with --dart-define-from-file=integration_test/test_account.json '
          '(see this file\'s header comment for the full command).',
    );

    // A prior interrupted run can leave a real session persisted in the
    // Keychain/secure storage — the app auto-restores whatever it finds
    // there and can land on /login, /onboarding (session restored but this
    // account/run never finished onboarding), or straight on the shell,
    // depending on exactly where a previous run stopped. Rather than
    // assume one fixed sequence, repeatedly check "are we at the goal, and
    // if not, is there a known action to advance" until we reach Profile.
    //
    // Clearing the stored session first forces a genuine fresh login every
    // run — iOS Keychain items survive app uninstall, so this is the only
    // reliable way to avoid restoring a session from many hours/relaunches
    // ago in this same debugging account, which can leave a stale-but-not-
    // yet-expired refresh token in a flaky state unrelated to what this
    // test is actually meant to verify.
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
      reason:
          'Should be in the authenticated shell (bottom nav visible) by now, '
          'via whichever of login/onboarding-skip/restored-session actually '
          'applied this run',
    );

    // A prior interrupted run could have left Work Mode on — make sure
    // we're actually starting from Personal before the Personal-mode
    // section below, rather than assuming it.
    await _ensureWorkMode(tester, active: false);

    // --- Personal-mode trip: create, confirm, delete ---
    final personalTripTitle =
        'SMOKETEST-personal-${DateTime.now().millisecondsSinceEpoch}';
    await tester.tap(_newTripEntryPoint());
    await _fillAndSubmitTripForm(tester, title: personalTripTitle);
    await _pumpUntilFound(tester, find.text(personalTripTitle));
    expect(find.text(personalTripTitle), findsOneWidget);
    await _deleteTrip(tester, personalTripTitle);

    // --- Work Mode: toggle on, confirm banner ---
    await _ensureWorkMode(tester, active: true);
    expect(
      find.textContaining('for $_testOrgName'),
      findsOneWidget,
      reason: 'Work Mode banner should show "<AppName> — for <org name>"',
    );

    // --- Work Mode trip: create, confirm, delete. This is the
    // regression guard for the org_cost_field_sources PostgREST embed
    // ambiguity that broke Work Mode trip creation for every org
    // (docs/Checklist.md, 2026-08-13) — that bug was structurally
    // invisible to mocked flutter test widget tests since it was a
    // live-Postgres query-shape error, not a Dart-level one.
    final workTripTitle =
        'SMOKETEST-workmode-${DateTime.now().millisecondsSinceEpoch}';
    await tester.tap(_newTripEntryPoint());
    await _pumpUntilFound(tester, find.byType(TextFormField));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('tagged to $_testOrgName'),
      findsOneWidget,
      reason: 'Work Mode trip creation should show the org-tagging notice',
    );
    await _fillAndSubmitTripForm(tester, title: workTripTitle);
    await _pumpUntilFound(tester, find.text(workTripTitle));
    expect(
      find.text(workTripTitle),
      findsOneWidget,
      reason:
          'Work Mode trip creation should succeed end-to-end against the '
          'real org_cost_fields/org_cost_field_sources query, not just '
          'render the form',
    );
    await _deleteTrip(tester, workTripTitle);

    // --- Toggle Work Mode back off, leaving state clean for re-runs ---
    await _ensureWorkMode(tester, active: false);

    // --- Sign out, leaving no persisted session for the next run ---
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 500));
    // Creating this session's first-ever trip earns the "First Steps"
    // badge, whose "New Badge Unlocked!" celebration dialog covers the
    // screen and absorbs every scroll drag below if still up — it can
    // appear on a delayed pump, not necessarily by the first check, so
    // this is folded into the same loop as the scroll rather than a
    // one-shot check beforehand.
    //
    // Profile's ListView is also long enough that "Sign Out" can be
    // outside the lazily-built sliver viewport entirely on a real device
    // (not just scrolled off — unbuilt), same issue profile_page_test.dart
    // works around with a taller test surface. Drag from a fixed raw
    // coordinate rather than scrollUntilVisible, whose widget-center-based
    // drag start point is less predictable on this screen.
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
    expect(find.text('Sign In'), findsOneWidget);
  });
}
