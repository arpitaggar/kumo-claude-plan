import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/onboarding/presentation/pages/onboarding_page.dart';

// OnboardingPage does not watch any provider in build() — onboardingProvider
// is only read inside _finish() — so no provider overrides are needed.
Widget _buildOnboarding() =>
    const ProviderScope(child: MaterialApp(home: OnboardingPage()));

void main() {
  group('OnboardingPage', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(_buildOnboarding());
      await tester.pump();
    });

    testWidgets('shows first slide title Plan Together', (tester) async {
      await tester.pumpWidget(_buildOnboarding());
      await tester.pump();
      expect(find.text('Plan Together'), findsOneWidget);
    });

    testWidgets('shows first slide subtitle', (tester) async {
      await tester.pumpWidget(_buildOnboarding());
      await tester.pump();
      expect(
        find.textContaining('itineraries with your whole group'),
        findsOneWidget,
      );
    });

    testWidgets('shows Skip button', (tester) async {
      await tester.pumpWidget(_buildOnboarding());
      await tester.pump();
      expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);
    });

    testWidgets('shows Next button on first slide', (tester) async {
      await tester.pumpWidget(_buildOnboarding());
      await tester.pump();
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
    });

    testWidgets('does not show Get Started on first slide', (tester) async {
      await tester.pumpWidget(_buildOnboarding());
      await tester.pump();
      expect(find.widgetWithText(FilledButton, 'Get Started'), findsNothing);
    });

    testWidgets('swiping to last slide shows Get Started', (tester) async {
      await tester.pumpWidget(_buildOnboarding());
      await tester.pump();

      // Swipe left twice to reach slide 3
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Get Started'), findsOneWidget);
    });

    testWidgets('second slide shows Split Every Expense', (tester) async {
      await tester.pumpWidget(_buildOnboarding());
      await tester.pump();

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Split Every Expense'), findsOneWidget);
    });
  });
}
