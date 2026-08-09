import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/main.dart';

void main() {
  group('StartupErrorApp', () {
    testWidgets('renders a visible error screen instead of a blank frame', (
      tester,
    ) async {
      // Regression coverage for the Android "stuck on launch screen"
      // bug: a startup failure used to rethrow out of main() with
      // runApp() never called, so nothing ever replaced the native
      // launch-screen placeholder — the app looked hung with zero
      // on-screen indication anything had gone wrong. main() now calls
      // runApp(StartupErrorApp(...)) on that failure path instead, so a
      // frame is always drawn (dismissing the native placeholder per
      // flutter_native_splash's own contract) and the actual error is
      // visible on the device.
      await tester.pumpWidget(
        const StartupErrorApp(error: 'Bad state: SUPABASE_URL is not set'),
      );

      expect(find.text('Kumo failed to start'), findsOneWidget);
      expect(find.text('Bad state: SUPABASE_URL is not set'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('stringifies a non-String error object', (tester) async {
      await tester.pumpWidget(
        StartupErrorApp(error: StateError('config missing')),
      );

      expect(find.textContaining('config missing'), findsOneWidget);
    });
  });
}
