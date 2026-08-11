import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/gamification/data/datasources/gamification_remote_datasource.dart';
import 'package:kumo_claude/features/gamification/data/models/xp_event_model.dart';
import 'package:kumo_claude/features/gamification/data/repositories/gamification_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockGamificationRemoteDataSource extends Mock
    implements GamificationRemoteDataSource {}

void main() {
  late MockGamificationRemoteDataSource dataSource;
  late GamificationRepositoryImpl repository;

  final tEvent = XpEventModel(
    id: 'evt-1',
    userId: 'user-1',
    amount: 10,
    reason: 'Planned a new trip',
    sourceType: 'trip_created',
    sourceId: 'trip-1',
    createdAt: DateTime.utc(2026),
  );

  setUp(() {
    dataSource = MockGamificationRemoteDataSource();
    repository = GamificationRepositoryImpl(dataSource);
  });

  group('fetchXpEvents', () {
    test('returns Right(events) on success', () async {
      when(
        () => dataSource.fetchXpEvents('user-1'),
      ).thenAnswer((_) async => [tEvent]);

      final result = await repository.fetchXpEvents('user-1');

      result.fold(
        (_) => fail('expected Right'),
        (events) => expect(events, [tEvent]),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.fetchXpEvents('user-1'),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.fetchXpEvents('user-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps UnexpectedException to UnexpectedFailure', () async {
      when(
        () => dataSource.fetchXpEvents('user-1'),
      ).thenThrow(UnexpectedException(message: 'boom'));

      final result = await repository.fetchXpEvents('user-1');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
