import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/ratings/domain/entities/rating.dart';
import 'package:kumo_claude/features/ratings/domain/repositories/rating_repository.dart';
import 'package:kumo_claude/features/ratings/domain/usecases/add_rating_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class FakeRating extends Fake implements Rating {}

void main() {
  late MockRatingRepository mockRepo;
  late AddRatingUseCase useCase;

  setUpAll(() {
    registerFallbackValue(FakeRating());
  });

  setUp(() {
    mockRepo = MockRatingRepository();
    useCase = AddRatingUseCase(mockRepo);
    when(() => mockRepo.addRating(any())).thenAnswer(
      (inv) async => Right(inv.positionalArguments[0] as Rating),
    );
  });

  group('AddRatingUseCase', () {
    test('calls repository.addRating once', () async {
      await useCase(
        itineraryId: 'it-1',
        targetName: 'Senso-ji',
        stars: 5,
        userId: 'alice',
        userName: 'Alice',
      );

      verify(() => mockRepo.addRating(any())).called(1);
    });

    test('clamps stars above 5 to 5', () async {
      await useCase(
        itineraryId: 'it-1',
        targetName: 'Museum',
        stars: 99,
        userId: 'alice',
        userName: 'Alice',
      );

      final captured =
          verify(() => mockRepo.addRating(captureAny())).captured;
      final rating = captured.first as Rating;
      expect(rating.stars, 5);
    });

    test('clamps stars below 1 to 1', () async {
      await useCase(
        itineraryId: 'it-1',
        targetName: 'Parking lot',
        stars: 0,
        userId: 'alice',
        userName: 'Alice',
      );

      final captured =
          verify(() => mockRepo.addRating(captureAny())).captured;
      final rating = captured.first as Rating;
      expect(rating.stars, 1);
    });

    test('empty comment string becomes null', () async {
      await useCase(
        itineraryId: 'it-1',
        targetName: 'Hotel',
        stars: 3,
        userId: 'alice',
        userName: 'Alice',
        comment: '   ',
      );

      final captured =
          verify(() => mockRepo.addRating(captureAny())).captured;
      final rating = captured.first as Rating;
      expect(rating.comment, isNull);
    });

    test('trims whitespace from comment', () async {
      await useCase(
        itineraryId: 'it-1',
        targetName: 'Restaurant',
        stars: 4,
        userId: 'alice',
        userName: 'Alice',
        comment: '  Great food!  ',
      );

      final captured =
          verify(() => mockRepo.addRating(captureAny())).captured;
      final rating = captured.first as Rating;
      expect(rating.comment, 'Great food!');
    });

    test('optional itemId is forwarded to rating', () async {
      await useCase(
        itineraryId: 'it-1',
        targetName: 'Guided tour',
        stars: 5,
        userId: 'alice',
        userName: 'Alice',
        itemId: 'item-42',
      );

      final captured =
          verify(() => mockRepo.addRating(captureAny())).captured;
      final rating = captured.first as Rating;
      expect(rating.itemId, 'item-42');
    });

    test('returns Right on success', () async {
      final result = await useCase(
        itineraryId: 'it-1',
        targetName: 'Sushi bar',
        stars: 5,
        userId: 'alice',
        userName: 'Alice',
      );

      expect(result.isRight(), isTrue);
    });

    test('propagates ServerFailure from repository', () async {
      when(() => mockRepo.addRating(any())).thenAnswer(
          (_) async => const Left(ServerFailure('Write failed')));

      final result = await useCase(
        itineraryId: 'it-1',
        targetName: 'Shop',
        stars: 2,
        userId: 'alice',
        userName: 'Alice',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
