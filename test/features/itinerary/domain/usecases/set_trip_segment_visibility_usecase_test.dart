import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/trip_segment_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/set_trip_segment_visibility_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockTripSegmentRepository extends Mock implements TripSegmentRepository {}

void main() {
  late MockTripSegmentRepository mockRepo;
  late SetTripSegmentVisibilityUseCase useCase;

  setUp(() {
    mockRepo = MockTripSegmentRepository();
    useCase = SetTripSegmentVisibilityUseCase(mockRepo);
  });

  test('delegates to repository with the provided id and flag', () async {
    when(() => mockRepo.setSegmentVisibility('seg-1', false))
        .thenAnswer((_) async => const Right(null));

    await useCase('seg-1', false);

    verify(() => mockRepo.setSegmentVisibility('seg-1', false)).called(1);
  });

  test('returns Right(null) on success', () async {
    when(() => mockRepo.setSegmentVisibility(any(), any()))
        .thenAnswer((_) async => const Right(null));

    final result = await useCase('seg-1', true);

    expect(result.isRight(), isTrue);
  });

  test('propagates ServerFailure from repository', () async {
    when(() => mockRepo.setSegmentVisibility(any(), any()))
        .thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('seg-1', false);

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
