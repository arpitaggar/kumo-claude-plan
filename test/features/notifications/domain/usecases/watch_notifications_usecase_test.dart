import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/notifications/domain/entities/app_notification.dart';
import 'package:kumo_claude/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:kumo_claude/features/notifications/domain/usecases/watch_notifications_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

void main() {
  test('delegates to the repository with the given userId', () async {
    final mockRepo = MockNotificationsRepository();
    final useCase = WatchNotificationsUseCase(mockRepo);
    when(
      () => mockRepo.watchNotifications('user-1'),
    ).thenAnswer((_) => Stream.value(const Right([])));

    final result = await useCase('user-1').first;

    verify(() => mockRepo.watchNotifications('user-1')).called(1);
    expect(result, const Right<Object, List<AppNotification>>([]));
  });
}
