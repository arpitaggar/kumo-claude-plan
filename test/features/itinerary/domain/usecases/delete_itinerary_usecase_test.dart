import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/itinerary_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/delete_itinerary_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockItineraryRepository extends Mock implements ItineraryRepository {}

void main() {
  late MockItineraryRepository mockRepo;
  late DeleteItineraryUseCase useCase;

  setUp(() {
    mockRepo = MockItineraryRepository();
    useCase = DeleteItineraryUseCase(mockRepo);
  });

  test('delegates to repository with the provided id', () async {
    when(() => mockRepo.deleteItinerary('it-1'))
        .thenAnswer((_) async => const Right(null));

    await useCase('it-1');

    verify(() => mockRepo.deleteItinerary('it-1')).called(1);
  });

  test('returns Right(null) on success', () async {
    when(() => mockRepo.deleteItinerary(any()))
        .thenAnswer((_) async => const Right(null));

    final result = await useCase('it-1');

    expect(result.isRight(), isTrue);
  });

  test('propagates ServerFailure from repository', () async {
    when(() => mockRepo.deleteItinerary(any()))
        .thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('it-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });

  test('propagates NetworkFailure from repository', () async {
    when(() => mockRepo.deleteItinerary(any()))
        .thenAnswer((_) async => const Left(NetworkFailure('No internet')));

    final result = await useCase('it-1');

    result.fold(
      (f) => expect(f, isA<NetworkFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
