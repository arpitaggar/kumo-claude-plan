import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/presentation/pages/login_page.dart';
import 'package:kumo_claude/features/auth/presentation/pages/password_reset_page.dart';
import 'package:kumo_claude/features/auth/presentation/pages/signup_page.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  setUpAll(initTestSupabase);

  // Returns a ProviderScope that supplies a real (mock) SharedPreferences so
  // AuthNotifier can initialise without hitting Supabase storage.
  Future<Widget> authScope(Widget page) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: page),
    );
  }

  // ── LoginPage ──────────────────────────────────────────────────────────────

  group('LoginPage', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(await authScope(const LoginPage()));
      await tester.pumpAndSettle();
    });

    testWidgets('shows tagline', (tester) async {
      await tester.pumpWidget(await authScope(const LoginPage()));
      await tester.pumpAndSettle();
      expect(find.text('Plan. Explore. Go.'), findsOneWidget);
    });

    testWidgets('shows subtitle', (tester) async {
      await tester.pumpWidget(await authScope(const LoginPage()));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to continue your journey'), findsOneWidget);
    });

    testWidgets('has Sign In button', (tester) async {
      await tester.pumpWidget(await authScope(const LoginPage()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('has Forgot password link', (tester) async {
      await tester.pumpWidget(await authScope(const LoginPage()));
      await tester.pumpAndSettle();
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('has Sign Up link', (tester) async {
      await tester.pumpWidget(await authScope(const LoginPage()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Sign Up'), findsOneWidget);
    });
  });

  // ── SignupPage ─────────────────────────────────────────────────────────────

  group('SignupPage', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(await authScope(const SignupPage()));
      await tester.pumpAndSettle();
    });

    testWidgets('shows heading', (tester) async {
      await tester.pumpWidget(await authScope(const SignupPage()));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('Create Account button is disabled initially', (tester) async {
      await tester.pumpWidget(await authScope(const SignupPage()));
      await tester.pumpAndSettle();
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('Create Account button enabled after ticking consent',
        (tester) async {
      await tester.pumpWidget(await authScope(const SignupPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('shows Privacy Policy in consent text', (tester) async {
      await tester.pumpWidget(await authScope(const SignupPage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Privacy Policy'), findsWidgets);
    });

    testWidgets('shows Terms of Service in consent text', (tester) async {
      await tester.pumpWidget(await authScope(const SignupPage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Terms of Service'), findsWidgets);
    });

    testWidgets('has Sign In link', (tester) async {
      await tester.pumpWidget(await authScope(const SignupPage()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Sign In'), findsOneWidget);
    });
  });

  // ── PasswordResetPage ──────────────────────────────────────────────────────

  group('PasswordResetPage', () {
    // PasswordResetPage does not watch any provider in build(), so a bare
    // ProviderScope suffices — no Supabase setup needed.
    Widget resetScope() => const ProviderScope(
          child: MaterialApp(home: PasswordResetPage()),
        );

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(resetScope());
      await tester.pump();
    });

    testWidgets('shows Reset Password AppBar title', (tester) async {
      await tester.pumpWidget(resetScope());
      await tester.pump();
      expect(find.text('Reset Password'), findsOneWidget);
    });

    testWidgets('shows Forgot your password heading', (tester) async {
      await tester.pumpWidget(resetScope());
      await tester.pump();
      expect(find.text('Forgot your password?'), findsOneWidget);
    });

    testWidgets('has Send Reset Link button', (tester) async {
      await tester.pumpWidget(resetScope());
      await tester.pump();
      expect(
        find.widgetWithText(ElevatedButton, 'Send Reset Link'),
        findsOneWidget,
      );
    });
  });
}
