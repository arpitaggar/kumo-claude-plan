import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/gamification/domain/entities/gamification_badge.dart';
import 'package:kumo_claude/features/gamification/domain/entities/xp_summary.dart';
import 'package:kumo_claude/features/gamification/presentation/providers/badge_unlock_notifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepositoryImpl {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

User _user(String id) =>
    User(id: id, email: '$id@example.com', createdAt: DateTime.utc(2026));

const _oneTripSummary = XpSummary(
  totalXp: 10,
  tripsCreated: 1,
  tripsCompleted: 0,
  postsPublished: 0,
  likesReceived: 0,
  followersGained: 0,
  commentsPosted: 0,
);

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
    container.listen(authNotifierProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('checkForNewBadges is a no-op while signed out', () async {
    final container = await buildContainer();

    final newBadges = await container
        .read(badgeUnlockNotifierProvider.notifier)
        .checkForNewBadges(_oneTripSummary);

    expect(newBadges, isEmpty);
  });

  test('a first-time-earned badge is returned and persisted', () async {
    final container = await buildContainer(initialUser: _user('user-1'));

    final newBadges = await container
        .read(badgeUnlockNotifierProvider.notifier)
        .checkForNewBadges(_oneTripSummary);

    expect(newBadges, [GamificationBadge.firstSteps]);
    expect(prefs.getStringList('badges_seen_user-1'), contains('first_steps'));
  });

  test('re-checking the same summary returns nothing — already seen', () async {
    final container = await buildContainer(initialUser: _user('user-1'));
    final notifier = container.read(badgeUnlockNotifierProvider.notifier);
    await notifier.checkForNewBadges(_oneTripSummary);

    final secondCheck = await notifier.checkForNewBadges(_oneTripSummary);

    expect(secondCheck, isEmpty);
  });

  test('a higher summary only returns the newly-crossed badges', () async {
    final container = await buildContainer(initialUser: _user('user-1'));
    final notifier = container.read(badgeUnlockNotifierProvider.notifier);
    await notifier.checkForNewBadges(_oneTripSummary);

    const fiveCompletedTrips = XpSummary(
      totalXp: 80,
      tripsCreated: 1,
      tripsCompleted: 5,
      postsPublished: 0,
      likesReceived: 0,
      followersGained: 0,
      commentsPosted: 0,
    );
    final newBadges = await notifier.checkForNewBadges(fiveCompletedTrips);

    // firstSteps was already seen; wanderer/globetrotter are newly crossed.
    // totalXp is kept under the centuryClub threshold so it doesn't also
    // cross that one in the same check.
    expect(newBadges.map((b) => b.key).toSet(), {
      GamificationBadge.wanderer.key,
      GamificationBadge.globetrotter.key,
    });
  });

  test("a second user's seen-set is independent", () async {
    final container = await buildContainer(
      initialUser: _user('user-1'),
      initialPrefs: {
        'badges_seen_user-2': ['first_steps'],
      },
    );
    final notifier = container.read(badgeUnlockNotifierProvider.notifier);
    await notifier.checkForNewBadges(_oneTripSummary); // user-1 earns it

    when(
      () => loginUseCase(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Right(_user('user-2')));
    await container
        .read(authNotifierProvider.notifier)
        .login(email: 'user-2@example.com', password: 'hunter22');

    // user-2 already has firstSteps in their seen-set, so it's not "new".
    final newBadges = await notifier.checkForNewBadges(_oneTripSummary);
    expect(newBadges, isEmpty);
  });

  test('resets to empty when the user signs out', () async {
    final container = await buildContainer(initialUser: _user('user-1'));
    final notifier = container.read(badgeUnlockNotifierProvider.notifier);
    await notifier.checkForNewBadges(_oneTripSummary);
    expect(container.read(badgeUnlockNotifierProvider), isNotEmpty);

    await container.read(authNotifierProvider.notifier).logout();

    expect(container.read(badgeUnlockNotifierProvider), isEmpty);
  });
}
