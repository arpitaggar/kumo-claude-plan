import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/presentation/pages/confirm_age_page.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  setUpAll(initTestSupabase);

  Widget buildPage() =>
      const ProviderScope(child: MaterialApp(home: ConfirmAgePage()));

  group('ConfirmAgePage', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
    });

    testWidgets('shows the heading and explanation', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(find.text('Confirm your date of birth'), findsOneWidget);
      expect(
        find.textContaining('Kumo accounts require you to be 18 or older'),
        findsOneWidget,
      );
    });

    testWidgets('shows the date of birth field with a placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(find.text('Date of birth'), findsOneWidget);
      expect(find.text('Select your date of birth'), findsOneWidget);
    });

    testWidgets('Continue button is disabled until a date is picked', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('tapping the date field opens the native date picker', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select your date of birth'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}
