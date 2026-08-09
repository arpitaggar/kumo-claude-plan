import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/legal/presentation/pages/privacy_policy_page.dart';
import 'package:kumo_claude/features/legal/presentation/pages/terms_page.dart';

void main() {
  group('PrivacyPolicyPage', () {
    testWidgets('renders page title in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
      expect(find.text('Privacy Policy'), findsWidgets);
    });

    testWidgets('contains effective date', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
      expect(find.textContaining('1 July 2026'), findsOneWidget);
    });

    testWidgets('contains data collection section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
      await tester.scrollUntilVisible(
        find.textContaining('Data We Collect'),
        200,
      );
      expect(find.textContaining('Data We Collect'), findsOneWidget);
    });

    testWidgets('contains GDPR rights section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
      await tester.scrollUntilVisible(find.textContaining('Your Rights'), 200);
      expect(find.textContaining('Your Rights'), findsOneWidget);
    });

    testWidgets('mentions account deletion (right to erasure)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
      await tester.scrollUntilVisible(
        find.textContaining('Delete Account'),
        200,
      );
      expect(find.textContaining('Delete Account'), findsWidgets);
    });

    testWidgets('mentions Supabase as sub-processor', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
      await tester.scrollUntilVisible(
        find.textContaining('Supabase').first,
        200,
      );
      expect(find.textContaining('Supabase'), findsWidgets);
    });

    testWidgets('has back navigation via AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyPage(),
                ),
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('TermsPage', () {
    testWidgets('renders page title in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));
      expect(find.text('Terms of Service'), findsWidgets);
    });

    testWidgets('contains effective date', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));
      expect(find.textContaining('1 July 2026'), findsOneWidget);
    });

    testWidgets('contains acceptable use section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));
      await tester.scrollUntilVisible(
        find.textContaining('Acceptable Use'),
        200,
      );
      expect(find.textContaining('Acceptable Use'), findsOneWidget);
    });

    testWidgets('contains termination section referencing Delete Account', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));
      await tester.scrollUntilVisible(
        find.textContaining('Delete Account'),
        200,
      );
      expect(find.textContaining('Delete Account'), findsOneWidget);
    });

    testWidgets('contains Katha AI disclaimer', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));
      await tester.scrollUntilVisible(
        find.textContaining('Katha AI').first,
        200,
      );
      expect(find.textContaining('Katha AI'), findsWidgets);
    });

    testWidgets('mentions governing law (England and Wales)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));
      await tester.scrollUntilVisible(
        find.textContaining('England and Wales'),
        200,
      );
      expect(find.textContaining('England and Wales'), findsOneWidget);
    });
  });
}
