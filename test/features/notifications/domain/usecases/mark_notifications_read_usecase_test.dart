import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:kumo_claude/features/notifications/domain/usecases/mark_notifications_read_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

void main() {
  late MockNotificationsRepository mockRepo;
  late MarkNotificationsReadUseCase useCase;

  setUp(() {
    mockRepo = MockNotificationsRepository();
    useCase = MarkNotificationsReadUseCase(mockRepo);
  });

  test('delegates to the repository with the given userId', () async {
    when(
      () => mockRepo.markAllRead('user-1'),
    ).thenAnswer((_) async => const Right(null));

    await useCase('user-1');

    verify(() => mockRepo.markAllRead('user-1')).called(1);
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.markAllRead(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('user-1');

    expect(result.isLeft(), isTrue);
  });
}
