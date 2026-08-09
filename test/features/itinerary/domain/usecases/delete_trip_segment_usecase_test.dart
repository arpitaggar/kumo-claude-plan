import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/trip_segment_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/delete_trip_segment_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockTripSegmentRepository extends Mock implements TripSegmentRepository {}

void main() {
  late MockTripSegmentRepository mockRepo;
  late DeleteTripSegmentUseCase useCase;

  setUp(() {
    mockRepo = MockTripSegmentRepository();
    useCase = DeleteTripSegmentUseCase(mockRepo);
  });

  test('delegates to repository with the provided id', () async {
    when(
      () => mockRepo.deleteSegment('seg-1'),
    ).thenAnswer((_) async => const Right(null));

    await useCase('seg-1');

    verify(() => mockRepo.deleteSegment('seg-1')).called(1);
  });

  test('returns Right(null) on success', () async {
    when(
      () => mockRepo.deleteSegment(any()),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase('seg-1');

    expect(result.isRight(), isTrue);
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.deleteSegment(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('seg-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
