import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_helpers.dart';

/// `authNotifierProvider` is typed to the concrete `AuthNotifier` (same
/// constraint noted in social_provider_test.dart), so switching between
/// signed-in users mid-test goes through the real `login()`/`logout()`
/// methods against mocked usecases, not a swapped-in fake notifier.
class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

User _user(String id) =>
    User(id: id, email: '$id@example.com', createdAt: DateTime.utc(2026));

void main() {
  setUpAll(initTestSupabase);

  late MockAuthRepository authRepo;
  late MockLoginUseCase loginUseCase;
  late MockLogoutUseCase logoutUseCase;
  late SharedPreferences prefs;

  Future<ProviderContainer> buildContainer({
    User? initialUser,
    Map<String, Object>? initialPrefs,
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs ?? {});
    prefs = await SharedPreferences.getInstance();

    authRepo = MockAuthRepository();
    loginUseCase = MockLoginUseCase();
    logoutUseCase = MockLogoutUseCase();
    when(authRepo.getCurrentUser).thenAnswer((_) async => Right(initialUser));
    when(logoutUseCase.call).thenAnswer((_) async => const Right(null));

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authNotifierProvider.overrideWith(
          (ref) => AuthNotifier(
            loginUseCase: loginUseCase,
            signupUseCase: MockSignupUseCase(),
            logoutUseCase: logoutUseCase,
            deleteAccountUseCase: MockDeleteAccountUseCase(),
            repository: authRepo,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Lets AuthNotifier's own async _checkCurrentUser() resolve before the
    // test inspects onboardingProvider's state.
    container.listen(authNotifierProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('is null while signed out', () async {
    final container = await buildContainer();

    expect(container.read(onboardingProvider), isNull);
  });

  test('is false for a signed-in user with no stored completion', () async {
    final container = await buildContainer(initialUser: _user('user-1'));

    expect(container.read(onboardingProvider), isFalse);
  });

  test('is true for a signed-in user who already completed it on this '
      'device', () async {
    final container = await buildContainer(
      initialUser: _user('user-1'),
      initialPrefs: {'onboarding_complete_user-1': true},
    );

    expect(container.read(onboardingProvider), isTrue);
  });

  test('markComplete() sets state to true and persists it', () async {
    final container = await buildContainer(initialUser: _user('user-1'));
    expect(container.read(onboardingProvider), isFalse);

    await container.read(onboardingProvider.notifier).markComplete();

    expect(container.read(onboardingProvider), isTrue);
    expect(prefs.getBool('onboarding_complete_user-1'), isTrue);
  });

  test(
    'markComplete() is a no-op while signed out (no user id to key by)',
    () async {
      final container = await buildContainer();

      await container.read(onboardingProvider.notifier).markComplete();

      expect(container.read(onboardingProvider), isNull);
    },
  );

  test('re-syncs to null when the user signs out', () async {
    final container = await buildContainer(initialUser: _user('user-1'));
    expect(container.read(onboardingProvider), isFalse);

    await container.read(authNotifierProvider.notifier).logout();

    expect(container.read(onboardingProvider), isNull);
  });

  test("switching to a different signed-in user re-syncs that user's own "
      'completion state', () async {
    final container = await buildContainer(
      initialUser: _user('user-1'),
      initialPrefs: {'onboarding_complete_user-2': true},
    );
    expect(container.read(onboardingProvider), isFalse); // user-1: unset

    when(
      () => loginUseCase(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Right(_user('user-2')));
    await container
        .read(authNotifierProvider.notifier)
        .login(email: 'user-2@example.com', password: 'hunter22');

    expect(container.read(onboardingProvider), isTrue); // user-2: set
  });
}
