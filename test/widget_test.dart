/// Widget test for Kumo main app.
///
/// Tests basic app initialization and UI rendering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/main.dart';

void main() {
  testWidgets('KumoApp renders home screen', (tester) async {
    // Build our app
    await tester.pumpWidget(const KumoApp());

    // Verify that the app title and content are present
    expect(find.text('Kumo'), findsWidgets);
    expect(find.text('Collaborative Travel Planning'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('Login button is tappable', (tester) async {
    await tester.pumpWidget(const KumoApp());

    // Find and tap the login button
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pump();

    // Verify snackbar appears
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
