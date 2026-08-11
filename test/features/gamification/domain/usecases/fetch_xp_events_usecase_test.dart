import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/gamification/domain/entities/xp_event.dart';
import 'package:kumo_claude/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:kumo_claude/features/gamification/domain/usecases/fetch_xp_events_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockGamificationRepository extends Mock
    implements GamificationRepository {}

void main() {
  late MockGamificationRepository repository;
  late FetchXpEventsUseCase usecase;

  setUp(() {
    repository = MockGamificationRepository();
    usecase = FetchXpEventsUseCase(repository);
  });

  test('delegates to the repository with the given userId', () async {
    final event = XpEvent(
      id: 'evt-1',
      userId: 'user-1',
      amount: 10,
      reason: 'Planned a new trip',
      sourceType: 'trip_created',
      sourceId: 'trip-1',
      createdAt: DateTime.utc(2026),
    );
    when(
      () => repository.fetchXpEvents('user-1'),
    ).thenAnswer((_) async => Right([event]));

    final result = await usecase('user-1');

    result.fold(
      (_) => fail('expected Right'),
      (events) => expect(events, [event]),
    );
    verify(() => repository.fetchXpEvents('user-1')).called(1);
  });

  test('propagates failure from repository', () async {
    when(
      () => repository.fetchXpEvents('user-1'),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await usecase('user-1');

    expect(result.isLeft(), isTrue);
  });
}
