// Drives the real app (real Supabase, real main()) end-to-end — unlike
// `flutter test`'s widget tests, which run against mocked
// providers/usecases and never touch the network. See
// `integration_test/README.md` for how to run this and the safety rules
// for anything beyond this file's read-only, unauthenticated coverage.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumo_claude/config/brand.dart';
import 'package:kumo_claude/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App launch (unauthenticated, read-only)', () {
    testWidgets('boots through the splash screen to the login page', (
      tester,
    ) async {
      await app.main();

      // Splash holds for ~1.6s before its own delayed navigation (see
      // splash_page_test.dart) — pump in slices rather than one long
      // pumpAndSettle so a real Supabase network round-trip (session
      // check) can't make this hang forever if it's ever slow.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.text('Sign In').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(
        find.text('Sign In'),
        findsOneWidget,
        reason:
            'Expected to land on the login page with no session persisted '
            '(a fresh keychain entry / signed-out state). If this fails, '
            'check whether a real session is cached on this machine from '
            'a prior manual run.',
      );
      expect(find.text(Brand.appName), findsWidgets);
    });
  });
}
