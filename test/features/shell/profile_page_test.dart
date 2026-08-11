import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/features/shell/profile_page.dart';
import 'package:kumo_claude/features/work_mode/presentation/providers/work_mode_provider.dart';

import '../../helpers/test_helpers.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool available,
  required bool active,
}) async {
  // The Profile page's ListView is long enough that a default 800x600 test
  // surface leaves "My Organizations"/"Sign Out" outside the lazily-built
  // sliver viewport entirely (not just scrolled-off — unbuilt).
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/profile',
    routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfilePage())],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isWorkModeAvailableProvider.overrideWithValue(available),
        isWorkModeActiveProvider.overrideWithValue(active),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestSupabase);

  group('"My Organizations" tile', () {
    testWidgets('hidden for a user with zero organizations', (tester) async {
      await _pump(tester, available: false, active: false);

      expect(find.text('My Organizations'), findsNothing);
    });

    testWidgets('visible for a user with an org even while Work Mode is off — '
        'org management should not require switching modes', (tester) async {
      await _pump(tester, available: true, active: false);

      expect(find.text('My Organizations'), findsOneWidget);
    });

    testWidgets('visible while Work Mode is active', (tester) async {
      await _pump(tester, available: true, active: true);

      expect(find.text('My Organizations'), findsOneWidget);
    });
  });

  group('Appearance tile', () {
    testWidgets('shows the normal, tappable theme tile when Work Mode is '
        'not active', (tester) async {
      await _pump(tester, available: true, active: false);

      expect(
        find.text('Theme: Onyx & Gold (locked by Work Mode)'),
        findsNothing,
      );
      expect(find.textContaining('Theme:'), findsOneWidget);
    });

    testWidgets('locks to a non-interactive Onyx & Gold row while Work '
        'Mode is active', (tester) async {
      await _pump(tester, available: true, active: true);

      expect(
        find.text('Theme: Onyx & Gold (locked by Work Mode)'),
        findsOneWidget,
      );
    });
  });
}
