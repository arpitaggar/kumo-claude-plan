import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/gamification/domain/entities/xp_event.dart';
import 'package:kumo_claude/features/gamification/domain/usecases/fetch_xp_events_usecase.dart';
import 'package:kumo_claude/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockFetchXpEventsUseCase extends Mock implements FetchXpEventsUseCase {}

XpEvent _event(String sourceType, int amount) => XpEvent(
  id: 'evt-$sourceType',
  userId: 'user-1',
  amount: amount,
  reason: sourceType,
  sourceType: sourceType,
  sourceId: 'src-1',
  createdAt: DateTime.utc(2026),
);

void main() {
  setUpAll(initTestSupabase);

  Future<ProviderContainer> buildContainer({
    User? initialUser,
    List<XpEvent> events = const [],
  }) async {
    final authRepo = MockAuthRepository();
    when(authRepo.getCurrentUser).thenAnswer((_) async => Right(initialUser));
    final logoutUseCase = MockLogoutUseCase();
    when(logoutUseCase.call).thenAnswer((_) async => const Right(null));

    final fetchXpEventsUseCase = MockFetchXpEventsUseCase();
    when(
      () => fetchXpEventsUseCase(any()),
    ).thenAnswer((_) async => Right(events));

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          (ref) => AuthNotifier(
            loginUseCase: MockLoginUseCase(),
            signupUseCase: MockSignupUseCase(),
            logoutUseCase: logoutUseCase,
            deleteAccountUseCase: MockDeleteAccountUseCase(),
            repository: authRepo,
          ),
        ),
        fetchXpEventsUseCaseProvider.overrideWithValue(fetchXpEventsUseCase),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authNotifierProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('xpEventsProvider is empty while signed out — never calls the '
      'usecase', () async {
    final container = await buildContainer();

    final events = await container.read(xpEventsProvider.future);

    expect(events, isEmpty);
  });

  test('xpEventsProvider fetches the signed-in user\'s events', () async {
    final container = await buildContainer(
      initialUser: User(
        id: 'user-1',
        email: 'user-1@example.com',
        createdAt: DateTime.utc(2026),
      ),
      events: [_event('trip_created', 10), _event('post_published', 15)],
    );

    final events = await container.read(xpEventsProvider.future);

    expect(events, hasLength(2));
  });

  test('xpSummaryProvider derives totals from xpEventsProvider', () async {
    final container = await buildContainer(
      initialUser: User(
        id: 'user-1',
        email: 'user-1@example.com',
        createdAt: DateTime.utc(2026),
      ),
      events: [_event('trip_created', 10), _event('trip_completed', 30)],
    );
    await container.read(xpEventsProvider.future);

    final summary = container.read(xpSummaryProvider);

    expect(summary.value?.totalXp, 40);
    expect(summary.value?.tripsCreated, 1);
    expect(summary.value?.tripsCompleted, 1);
  });
}
