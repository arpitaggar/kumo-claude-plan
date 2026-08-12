import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/hitchhiker/domain/entities/hitchhiker.dart';
import 'package:kumo_claude/features/hitchhiker/domain/repositories/hitchhiker_repository.dart';
import 'package:kumo_claude/features/hitchhiker/domain/usecases/list_hitchhikers_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerRepository extends Mock implements HitchhikerRepository {}

void main() {
  late MockHitchhikerRepository mockRepo;
  late ListHitchhikersUseCase useCase;

  final tHitchhikers = [
    Hitchhiker(
      id: 'hh-1',
      itineraryId: 'trip-1',
      displayName: 'Priya',
      accessToken: 'tok-1',
      createdAt: DateTime(2026),
    ),
    Hitchhiker(
      id: 'hh-2',
      itineraryId: 'trip-1',
      displayName: 'Sam',
      accessToken: 'tok-2',
      createdAt: DateTime(2026, 1, 2),
      revokedAt: DateTime(2026, 1, 3),
    ),
  ];

  setUp(() {
    mockRepo = MockHitchhikerRepository();
    useCase = ListHitchhikersUseCase(mockRepo);
  });

  test(
    'delegates to repository.listHitchhikers with the given trip id',
    () async {
      when(
        () => mockRepo.listHitchhikers('trip-1'),
      ).thenAnswer((_) async => Right(tHitchhikers));

      await useCase('trip-1');

      verify(() => mockRepo.listHitchhikers('trip-1')).called(1);
    },
  );

  test('returns Right(list) including revoked entries, on success', () async {
    when(
      () => mockRepo.listHitchhikers(any()),
    ).thenAnswer((_) async => Right(tHitchhikers));

    final result = await useCase('trip-1');

    result.fold((_) => fail('expected Right'), (list) {
      expect(list, hasLength(2));
      expect(list[1].isRevoked, isTrue);
    });
  });

  test('propagates a Failure from the repository', () async {
    when(
      () => mockRepo.listHitchhikers(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('db error')));

    final result = await useCase('trip-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
