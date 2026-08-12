import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/hitchhiker/domain/repositories/hitchhiker_repository.dart';
import 'package:kumo_claude/features/hitchhiker/domain/usecases/revoke_hitchhiker_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerRepository extends Mock implements HitchhikerRepository {}

void main() {
  late MockHitchhikerRepository mockRepo;
  late RevokeHitchhikerUseCase useCase;

  setUp(() {
    mockRepo = MockHitchhikerRepository();
    useCase = RevokeHitchhikerUseCase(mockRepo);
  });

  test('delegates to repository.revokeHitchhiker with the given id', () async {
    when(
      () => mockRepo.revokeHitchhiker('hh-1'),
    ).thenAnswer((_) async => const Right(null));

    await useCase('hh-1');

    verify(() => mockRepo.revokeHitchhiker('hh-1')).called(1);
  });

  test('returns Right(null) on success', () async {
    when(
      () => mockRepo.revokeHitchhiker(any()),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase('hh-1');

    expect(result.isRight(), isTrue);
  });

  test('propagates a Failure from the repository (already revoked / not '
      'the trip owner)', () async {
    when(() => mockRepo.revokeHitchhiker(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          'Hitchhiker not found, already revoked, or you do not own this trip',
        ),
      ),
    );

    final result = await useCase('hh-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
