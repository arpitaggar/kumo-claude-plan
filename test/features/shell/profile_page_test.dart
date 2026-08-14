import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:kumo_claude/features/shell/profile_page.dart';
import 'package:kumo_claude/features/work_mode/presentation/providers/work_mode_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_helpers.dart';

// These tests are about Work Mode tile visibility, not auth — overriding
// authNotifierProvider with a repository that resolves immediately (rather
// than leaving the real AuthRepositoryImpl wired up) keeps them from
// depending on AuthRepositoryImpl.getCurrentUser()'s session-restore-retry
// loop (see that method's doc comment), which needs real pumped time this
// helper's plain pumpAndSettle() doesn't give it.
class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

Future<void> _pump(
  WidgetTester tester, {
  required bool available,
  required bool active,
}) async {
  // The Profile page's ListView is long enough that a default 800x600 test
  // surface leaves "My Organizations"/"Sign Out" outside the lazily-built
  // sliver viewport entirely (not just scrolled-off — unbuilt).
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/profile',
    routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfilePage())],
  );

  final authRepo = MockAuthRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(
        id: 'user-1',
        email: 'u@example.com',
        displayName: 'Arpit',
        createdAt: DateTime.utc(2026),
      ),
    ),
  );

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isWorkModeAvailableProvider.overrideWithValue(available),
        isWorkModeActiveProvider.overrideWithValue(active),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authNotifierProvider.overrideWith(
          (ref) => AuthNotifier(
            loginUseCase: MockLoginUseCase(),
            signupUseCase: MockSignupUseCase(),
            logoutUseCase: MockLogoutUseCase(),
            deleteAccountUseCase: MockDeleteAccountUseCase(),
            repository: authRepo,
          ),
        ),
        // ProfilePage renders GamificationCard, which now actually fires
        // (previously masked by authNotifierProvider never resolving to a
        // real user in this test) — not what these tests are about.
        xpEventsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestSupabase);

  group('"My Organizations" tile', () {
    testWidgets('hidden for a user with zero organizations', (tester) async {
      await _pump(tester, available: false, active: false);

      expect(find.text('My Organizations'), findsNothing);
    });

    testWidgets('visible for a user with an org even while Work Mode is off — '
        'org management should not require switching modes', (tester) async {
      await _pump(tester, available: true, active: false);

      expect(find.text('My Organizations'), findsOneWidget);
    });

    testWidgets('visible while Work Mode is active', (tester) async {
      await _pump(tester, available: true, active: true);

      expect(find.text('My Organizations'), findsOneWidget);
    });
  });

  group('Appearance tile', () {
    testWidgets('shows the normal, tappable theme tile when Work Mode is '
        'not active', (tester) async {
      await _pump(tester, available: true, active: false);

      expect(
        find.text('Theme: Onyx & Gold (locked by Work Mode)'),
        findsNothing,
      );
      expect(find.textContaining('Theme:'), findsOneWidget);
    });

    testWidgets('locks to a non-interactive Onyx & Gold row while Work '
        'Mode is active', (tester) async {
      await _pump(tester, available: true, active: true);

      expect(
        find.text('Theme: Onyx & Gold (locked by Work Mode)'),
        findsOneWidget,
      );
    });
  });
}
