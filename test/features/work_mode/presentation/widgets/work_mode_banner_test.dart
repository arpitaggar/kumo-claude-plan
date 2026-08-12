import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
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
import 'package:kumo_claude/features/work_mode/presentation/widgets/work_mode_banner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

Organization _org(String id) => Organization(
  id: id,
  name: 'Acme Corp',
  slug: id,
  ownerId: 'owner-1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> _pump(
  WidgetTester tester,
  List<Organization> orgs, {
  Map<String, Object>? initialPrefs,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs ?? {});
  final prefs = await SharedPreferences.getInstance();
  final authRepo = MockAuthRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(
        id: 'user-1',
        email: 'user-1@example.com',
        createdAt: DateTime.utc(2026),
      ),
    ),
  );
  final logoutUseCase = MockLogoutUseCase();
  when(logoutUseCase.call).thenAnswer((_) async => const Right(null));

  await tester.pumpWidget(
    ProviderScope(
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
      child: const MaterialApp(home: Scaffold(body: WorkModeBanner())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets('renders nothing for a user with zero organizations', (
    tester,
  ) async {
    await _pump(tester, const []);

    expect(find.byType(Switch), findsNothing);
    expect(find.text('Personal'), findsNothing);
  });

  testWidgets('shows "Personal" with the switch off by default', (
    tester,
  ) async {
    await _pump(tester, [_org('org-1')]);

    expect(find.text('Personal'), findsOneWidget);
    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isFalse);
  });

  testWidgets('tapping the switch turns on Work Mode and shows the org name', (
    tester,
  ) async {
    await _pump(tester, [_org('org-1')]);
    expect(find.text('Personal'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Kumo — for Acme Corp'), findsOneWidget);
    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isTrue);
  });
}
