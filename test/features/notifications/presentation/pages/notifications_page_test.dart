import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/notifications/domain/entities/app_notification.dart';
import 'package:kumo_claude/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:kumo_claude/features/notifications/presentation/pages/notifications_page.dart';
import 'package:kumo_claude/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

class MockAuthRepository extends Mock implements AuthRepositoryImpl {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

/// Same fixture pattern as social_provider_test.dart's `_buildAuthNotifier`
/// — a real `AuthNotifier` backed by a mocked repository, so
/// `notificationFeedProvider`'s `ref.watch(authNotifierProvider)` dependency
/// resolves the same way it does in the running app.
AuthNotifier _buildAuthNotifier(User user) {
  final repo = MockAuthRepository();
  when(repo.getCurrentUser).thenAnswer((_) async => Right(user));
  return AuthNotifier(
    loginUseCase: MockLoginUseCase(),
    signupUseCase: MockSignupUseCase(),
    logoutUseCase: MockLogoutUseCase(),
    deleteAccountUseCase: MockDeleteAccountUseCase(),
    repository: repo,
  );
}

final _user = User(
  id: 'user-1',
  email: 'me@example.com',
  createdAt: DateTime(2026),
);

void main() {
  setUpAll(initTestSupabase);

  late MockNotificationsRepository mockRepo;

  setUp(() {
    mockRepo = MockNotificationsRepository();
    when(
      () => mockRepo.markAllRead(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  Future<void> pumpNotificationsPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(mockRepo),
          authNotifierProvider.overrideWith((ref) => _buildAuthNotifier(_user)),
        ],
        child: const MaterialApp(home: NotificationsPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows a follow notification tile', (tester) async {
    when(() => mockRepo.watchNotifications('user-1')).thenAnswer(
      (_) => Stream.value(
        Right([
          AppNotification(
            id: 'n-1',
            actorId: 'actor-1',
            actorName: 'Alice',
            type: NotificationType.follow,
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        ]),
      ),
    );

    await pumpNotificationsPage(tester);

    expect(find.text('Alice started following you'), findsOneWidget);
  });

  testWidgets('shows the empty state when there is no activity', (
    tester,
  ) async {
    when(
      () => mockRepo.watchNotifications('user-1'),
    ).thenAnswer((_) => Stream.value(const Right([])));

    await pumpNotificationsPage(tester);

    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets('marks all notifications read on open', (tester) async {
    when(() => mockRepo.watchNotifications('user-1')).thenAnswer(
      (_) => Stream.value(
        Right([
          AppNotification(
            id: 'n-1',
            actorId: 'actor-1',
            actorName: 'Alice',
            type: NotificationType.like,
            postId: 'post-1',
            postTitle: 'Tokyo Summer 2026',
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        ]),
      ),
    );

    await pumpNotificationsPage(tester);
    // One more pump for the addPostFrameCallback that fires markAllRead.
    await tester.pump();

    verify(() => mockRepo.markAllRead('user-1')).called(1);
  });
}
