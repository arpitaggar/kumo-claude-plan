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
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';
import 'package:kumo_claude/features/organization/presentation/providers/organization_provider.dart';
import 'package:kumo_claude/features/work_mode/presentation/providers/work_mode_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_helpers.dart';

/// `authNotifierProvider` is typed to the concrete `AuthNotifier` (same
/// constraint noted in onboarding_provider_test.dart), so switching between
/// signed-in users mid-test goes through the real `login()`/`logout()`
/// methods against mocked usecases, not a swapped-in fake notifier.
class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

User _user(String id) =>
    User(id: id, email: '$id@example.com', createdAt: DateTime.utc(2026));

Organization _org(String id, {String name = 'Acme Corp'}) => Organization(
  id: id,
  name: name,
  slug: id,
  ownerId: 'owner-1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
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
    List<Organization> orgs = const [],
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
        myOrganizationsProvider.overrideWith((ref) async => orgs),
      ],
    );
    addTearDown(container.dispose);
    // Lets AuthNotifier's own async _checkCurrentUser() resolve, and
    // myOrganizationsProvider resolve, before the test inspects state.
    container
      ..listen(authNotifierProvider, (_, _) {})
      ..listen(myOrganizationsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  group('workModeProvider persistence', () {
    test('is null while signed out', () async {
      final container = await buildContainer();

      expect(container.read(workModeProvider), isNull);
    });

    test(
      'defaults to false for a signed-in user with no stored preference',
      () async {
        final container = await buildContainer(
          initialUser: _user('user-1'),
          orgs: [_org('org-1')],
        );

        expect(container.read(workModeProvider), isFalse);
      },
    );

    test('is true for a signed-in user who last chose Work Mode on this '
        'device', () async {
      final container = await buildContainer(
        initialUser: _user('user-1'),
        initialPrefs: {'work_mode_user-1': true},
        orgs: [_org('org-1')],
      );

      expect(container.read(workModeProvider), isTrue);
    });

    test('setWorkMode(true) persists and updates state', () async {
      final container = await buildContainer(
        initialUser: _user('user-1'),
        orgs: [_org('org-1')],
      );
      expect(container.read(workModeProvider), isFalse);

      await container.read(workModeProvider.notifier).setWorkMode(value: true);

      expect(container.read(workModeProvider), isTrue);
      expect(prefs.getBool('work_mode_user-1'), isTrue);
    });

    test('setWorkMode() is a no-op while signed out', () async {
      final container = await buildContainer();

      await container.read(workModeProvider.notifier).setWorkMode(value: true);

      expect(container.read(workModeProvider), isNull);
    });

    test('re-syncs to null when the user signs out', () async {
      final container = await buildContainer(
        initialUser: _user('user-1'),
        initialPrefs: {'work_mode_user-1': true},
        orgs: [_org('org-1')],
      );
      expect(container.read(workModeProvider), isTrue);

      await container.read(authNotifierProvider.notifier).logout();

      expect(container.read(workModeProvider), isNull);
    });

    test("switching to a different signed-in user re-syncs that user's own "
        'preference', () async {
      final container = await buildContainer(
        initialUser: _user('user-1'),
        initialPrefs: {'work_mode_user-2': true},
        orgs: [_org('org-1')],
      );
      expect(container.read(workModeProvider), isFalse); // user-1: unset

      when(
        () => loginUseCase(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(_user('user-2')));
      await container
          .read(authNotifierProvider.notifier)
          .login(email: 'user-2@example.com', password: 'hunter22');

      expect(container.read(workModeProvider), isTrue); // user-2: set
    });
  });

  group('isWorkModeAvailableProvider', () {
    test('is false for a user with zero organizations', () async {
      final container = await buildContainer(initialUser: _user('user-1'));

      expect(container.read(isWorkModeAvailableProvider), isFalse);
    });

    test('is true for a user with at least one organization', () async {
      final container = await buildContainer(
        initialUser: _user('user-1'),
        orgs: [_org('org-1')],
      );

      expect(container.read(isWorkModeAvailableProvider), isTrue);
    });
  });

  group('isWorkModeActiveProvider', () {
    test('is false when the user chose Work Mode but has no org (self-heals '
        'a stale preference)', () async {
      final container = await buildContainer(
        initialUser: _user('user-1'),
        initialPrefs: {'work_mode_user-1': true},
      );

      expect(container.read(isWorkModeActiveProvider), isFalse);
    });

    test('is true only once the user opts in and has an org', () async {
      final container = await buildContainer(
        initialUser: _user('user-1'),
        orgs: [_org('org-1')],
      );
      expect(container.read(isWorkModeActiveProvider), isFalse);

      await container.read(workModeProvider.notifier).setWorkMode(value: true);

      expect(container.read(isWorkModeActiveProvider), isTrue);
    });
  });

  group('currentWorkOrgProvider', () {
    test('is null with zero organizations', () async {
      final container = await buildContainer(initialUser: _user('user-1'));

      expect(container.read(currentWorkOrgProvider), isNull);
    });

    test('is the single organization when the user has exactly one', () async {
      final org = _org('org-1');
      final container = await buildContainer(
        initialUser: _user('user-1'),
        orgs: [org],
      );

      expect(container.read(currentWorkOrgProvider), org);
    });

    test('falls back to the first organization (no picker) when the user '
        'belongs to more than one', () async {
      final first = _org('org-1', name: 'First Co');
      final second = _org('org-2', name: 'Second Co');
      final container = await buildContainer(
        initialUser: _user('user-1'),
        orgs: [first, second],
      );

      expect(container.read(currentWorkOrgProvider), first);
    });
  });
}
