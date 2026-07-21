import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/settings/presentation/pages/privacy_settings_page.dart';

// Override currentUserProfileProvider with a pre-resolved null profile so the
// page renders _PrivacyBody immediately without hitting Supabase.
Widget _buildPage() => ProviderScope(
      overrides: [
        currentUserProfileProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: PrivacySettingsPage()),
    );

void main() {
  group('PrivacySettingsPage', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
    });

    testWidgets('shows Privacy AppBar title', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      expect(find.text('Privacy'), findsOneWidget);
    });

    testWidgets('shows Discoverability section heading', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      expect(find.text('Discoverability'), findsOneWidget);
    });

    testWidgets('shows discoverability toggle', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('shows Legal section heading', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      expect(find.text('Legal'), findsOneWidget);
    });

    testWidgets('shows Privacy Policy tile', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('shows Terms of Service tile', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('shows Danger zone section heading', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      expect(find.text('Danger zone'), findsOneWidget);
    });

    testWidgets('shows Delete Account tile', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('tapping Delete Account shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete account?'), findsOneWidget);
    });

    testWidgets('confirmation dialog has Cancel and Delete buttons',
        (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete my account'), findsOneWidget);
    });

    testWidgets('cancelling delete dialog dismisses it', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete account?'), findsNothing);
    });
  });
}
