import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/ratings/domain/repositories/rating_repository.dart';
import 'package:kumo_claude/features/ratings/domain/usecases/delete_rating_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

void main() {
  late MockRatingRepository mockRepo;
  late DeleteRatingUseCase useCase;

  setUp(() {
    mockRepo = MockRatingRepository();
    useCase = DeleteRatingUseCase(mockRepo);
  });

  test('delegates to repository with the given id', () async {
    when(
      () => mockRepo.deleteRating('rating-1'),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase('rating-1');

    verify(() => mockRepo.deleteRating('rating-1')).called(1);
    expect(result, const Right<Failure, void>(null));
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.deleteRating(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('rating-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
