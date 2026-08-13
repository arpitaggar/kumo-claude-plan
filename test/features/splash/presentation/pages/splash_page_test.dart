import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/config/brand.dart';
import 'package:kumo_claude/features/splash/presentation/pages/splash_page.dart';

import '../../../../helpers/test_helpers.dart';

Future<GoRouter> _pump(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login screen')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  return router;
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets('renders the brand name, logo, and tagline mid-animation', (
    tester,
  ) async {
    await _pump(tester);
    // Pump partway through the 1600ms entrance animation, before the
    // post-animation navigation delay fires.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(Brand.appName), findsOneWidget);
    expect(find.text(Brand.tagline), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('navigates to /login once the entrance animation and the '
      'post-animation delay both finish', (tester) async {
    final router = await _pump(tester);
    expect(router.state.uri.path, '/splash');

    // Animation is 1600ms, followed by a 350ms delay before navigating.
    // Pump past the animation first so its completion future resolves
    // and schedules the delayed-navigation timer, then pump again to
    // let that timer fire, then flush the resulting navigation frame.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(router.state.uri.path, '/login');
    expect(find.text('Login screen'), findsOneWidget);
  });

  testWidgets('does not navigate before the animation finishes', (
    tester,
  ) async {
    final router = await _pump(tester);

    await tester.pump(const Duration(milliseconds: 800));

    expect(router.state.uri.path, '/splash');
  });
}
