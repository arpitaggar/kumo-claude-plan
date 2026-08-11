import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_theme.dart';
import 'package:kumo_claude/features/itinerary/presentation/extensions/trip_theme_context_extension.dart';

void main() {
  Future<BuildContext> pumpContext(
    WidgetTester tester, {
    required ColorScheme colorScheme,
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: colorScheme),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets(
    'withContext replaces the classic preset with the active app theme\'s '
    'colors',
    (tester) async {
      const scheme = ColorScheme.light(
        primary: Color(0xFF123456),
        primaryContainer: Color(0xFF654321),
      );
      final context = await pumpContext(tester, colorScheme: scheme);

      final result = TripTheme.classic.withContext(context);

      expect(result.primary, scheme.primary);
      expect(result.gradientStart, scheme.primaryContainer);
      expect(result.gradientEnd, scheme.primary);
      expect(result.backgroundTint, Theme.of(context).scaffoldBackgroundColor);
      // Non-color fields pass through unchanged.
      expect(result.key, TripTheme.classic.key);
      expect(result.label, TripTheme.classic.label);
      expect(result.emoji, TripTheme.classic.emoji);
    },
  );

  testWidgets('withContext leaves a non-classic preset untouched', (
    tester,
  ) async {
    final context = await pumpContext(
      tester,
      colorScheme: const ColorScheme.light(),
    );

    final result = TripTheme.sakura.withContext(context);

    expect(result, TripTheme.sakura);
  });
}
