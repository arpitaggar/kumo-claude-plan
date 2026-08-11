import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/config/theme_provider.dart';
import 'package:kumo_claude/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
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

import '../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepositoryImpl {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

User _user(String id) =>
    User(id: id, email: '$id@example.com', createdAt: DateTime.utc(2026));

Organization _org(String id) => Organization(
  id: id,
  name: 'Acme Corp',
  slug: id,
  ownerId: 'owner-1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(initTestSupabase);

  Future<ProviderContainer> buildContainer({
    Map<String, Object>? initialPrefs,
    List<Organization> orgs = const [],
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs ?? {});
    final prefs = await SharedPreferences.getInstance();

    final authRepo = MockAuthRepository();
    when(
      authRepo.getCurrentUser,
    ).thenAnswer((_) async => Right(_user('user-1')));
    final logoutUseCase = MockLogoutUseCase();
    when(logoutUseCase.call).thenAnswer((_) async => const Right(null));

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authNotifierProvider.overrideWith(
          (ref) => AuthNotifier(
            loginUseCase: MockLoginUseCase(),
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
    container.listen(authNotifierProvider, (_, _) {});
    container.listen(myOrganizationsProvider, (_, _) {});
    // Triggers ThemeNotifier's construction (and its async _loadSaved())
    // early enough for the delay below to let it finish.
    container.read(themeProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test(
    'passes through the stored personal theme when Work Mode is off',
    () async {
      final container = await buildContainer(
        initialPrefs: {'kumo_theme': KumoTheme.sunsetCoral.name},
        orgs: [_org('org-1')],
      );

      expect(container.read(effectiveThemeProvider), KumoTheme.sunsetCoral);
    },
  );

  test('forces Onyx & Gold whenever Work Mode is active', () async {
    final container = await buildContainer(
      initialPrefs: {'kumo_theme': KumoTheme.sunsetCoral.name},
      orgs: [_org('org-1')],
    );
    await container.read(workModeProvider.notifier).setWorkMode(value: true);

    expect(container.read(effectiveThemeProvider), KumoTheme.onyxGold);
  });

  test(
    'restores the exact prior personal theme after leaving Work Mode',
    () async {
      final container = await buildContainer(
        initialPrefs: {'kumo_theme': KumoTheme.sunsetCoral.name},
        orgs: [_org('org-1')],
      );
      final notifier = container.read(workModeProvider.notifier);

      await notifier.setWorkMode(value: true);
      expect(container.read(effectiveThemeProvider), KumoTheme.onyxGold);

      await notifier.setWorkMode(value: false);
      expect(container.read(effectiveThemeProvider), KumoTheme.sunsetCoral);
    },
  );
}
