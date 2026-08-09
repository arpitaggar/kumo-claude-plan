import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/trip_segment_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/update_trip_segment_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockTripSegmentRepository extends Mock implements TripSegmentRepository {}

void main() {
  late MockTripSegmentRepository mockRepo;
  late UpdateTripSegmentUseCase useCase;

  const tSegment = TripSegment(
    id: 'seg-1',
    itineraryId: 'it-1',
    orderIndex: 0,
    mode: TransportMode.flight,
    origin: Waypoint(name: 'Munich', latitude: 48.1351, longitude: 11.5820),
    destination: Waypoint(
      name: 'Bangkok',
      latitude: 13.7563,
      longitude: 100.5018,
    ),
  );

  setUp(() {
    mockRepo = MockTripSegmentRepository();
    useCase = UpdateTripSegmentUseCase(mockRepo);
  });

  test(
    'delegates to repository.updateSegment with the given segment',
    () async {
      when(
        () => mockRepo.updateSegment(tSegment),
      ).thenAnswer((_) async => const Right(tSegment));

      await useCase(tSegment);

      verify(() => mockRepo.updateSegment(tSegment)).called(1);
    },
  );

  test('returns Right(segment) on success', () async {
    when(
      () => mockRepo.updateSegment(tSegment),
    ).thenAnswer((_) async => const Right(tSegment));

    final result = await useCase(tSegment);

    expect(result.isRight(), isTrue);
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.updateSegment(tSegment),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(tSegment);

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
