import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/age_gate_provider.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/profile/domain/entities/user_profile.dart';
import 'package:kumo_claude/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:kumo_claude/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

/// Same fixture pattern as onboarding_provider_test.dart — authNotifierProvider
/// is typed to the concrete AuthNotifier, so signing in/out mid-test goes
/// through the real login()/logout() methods against mocked usecases.
class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

User _user(String id) =>
    User(id: id, email: '$id@example.com', createdAt: DateTime.utc(2026));

UserProfile _profile(String id, {DateTime? ageVerifiedAt}) => UserProfile(
  id: id,
  email: '$id@example.com',
  displayName: id,
  isSearchable: true,
  profileVisibility: 'public',
  contactVisibility: 'collaborators_only',
  unitsPreference: 'metric',
  travelPreferenceTags: const [],
  updatedAt: DateTime.utc(2026),
  ageVerifiedAt: ageVerifiedAt,
);

void main() {
  setUpAll(initTestSupabase);

  late MockAuthRepository authRepo;
  late MockLoginUseCase loginUseCase;
  late MockLogoutUseCase logoutUseCase;
  late MockUserProfileRepository profileRepo;

  Future<ProviderContainer> buildContainer({
    User? initialUser,
    UserProfile? profile,
  }) async {
    authRepo = MockAuthRepository();
    loginUseCase = MockLoginUseCase();
    logoutUseCase = MockLogoutUseCase();
    profileRepo = MockUserProfileRepository();
    when(authRepo.getCurrentUser).thenAnswer((_) async => Right(initialUser));
    when(logoutUseCase.call).thenAnswer((_) async => const Right(null));
    when(profileRepo.getOwnProfile).thenAnswer(
      (_) async => Right(profile ?? _profile(initialUser?.id ?? '')),
    );

    final container = ProviderContainer(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(profileRepo),
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
    // Keep both providers alive/reactive so their async chains actually run
    // and propagate — AuthNotifier's own _checkCurrentUser(), then
    // AgeGateNotifier's _sync() reacting to that resolution.
    container.listen(authNotifierProvider, (_, _) {});
    container.listen(ageGateProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('is null while signed out', () async {
    final container = await buildContainer();

    expect(container.read(ageGateProvider), isNull);
  });

  test(
    'is true for a signed-in user whose profile has age_verified_at set',
    () async {
      final container = await buildContainer(
        initialUser: _user('user-1'),
        profile: _profile('user-1', ageVerifiedAt: DateTime.utc(2026, 1, 1)),
      );

      expect(container.read(ageGateProvider), isTrue);
    },
  );

  test('is false for a signed-in user whose profile has no age_verified_at '
      '(invite-created account pending confirm-age)', () async {
    final container = await buildContainer(
      initialUser: _user('user-1'),
      profile: _profile('user-1'),
    );

    expect(container.read(ageGateProvider), isFalse);
  });

  test('is null when the profile fetch itself fails', () async {
    final container = await buildContainer(initialUser: _user('user-1'));
    when(
      profileRepo.getOwnProfile,
    ).thenAnswer((_) async => const Left(ServerFailure('db error')));

    // Trigger a fresh sync for this user by forcing a sign-out/sign-in
    // cycle, since buildContainer's own initial sync already resolved.
    when(
      () => loginUseCase(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Right(_user('user-1')));
    await container.read(authNotifierProvider.notifier).logout();
    await container
        .read(authNotifierProvider.notifier)
        .login(email: 'user-1@example.com', password: 'hunter22');

    expect(container.read(ageGateProvider), isNull);
  });

  test('re-syncs to null when the user signs out', () async {
    final container = await buildContainer(
      initialUser: _user('user-1'),
      profile: _profile('user-1', ageVerifiedAt: DateTime.utc(2026, 1, 1)),
    );
    expect(container.read(ageGateProvider), isTrue);

    await container.read(authNotifierProvider.notifier).logout();

    expect(container.read(ageGateProvider), isNull);
  });

  test('markVerified() sets state to true immediately, without re-fetching '
      'the profile', () async {
    final container = await buildContainer(
      initialUser: _user('user-1'),
      profile: _profile('user-1'),
    );
    expect(container.read(ageGateProvider), isFalse);

    container.read(ageGateProvider.notifier).markVerified();

    expect(container.read(ageGateProvider), isTrue);
  });
}
