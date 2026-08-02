import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/trip_segment_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/reorder_trip_segments_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockTripSegmentRepository extends Mock implements TripSegmentRepository {}

void main() {
  late MockTripSegmentRepository mockRepo;
  late ReorderTripSegmentsUseCase useCase;

  const wA = Waypoint(name: 'Munich', latitude: 48.1351, longitude: 11.5820);
  const wB = Waypoint(name: 'Bangkok', latitude: 13.7563, longitude: 100.5018);
  const wC =
      Waypoint(name: 'Chiang Mai', latitude: 18.7883, longitude: 98.9853);

  TripSegment segment(String id, int orderIndex) => TripSegment(
        id: id,
        itineraryId: 'it-1',
        orderIndex: orderIndex,
        mode: TransportMode.flight,
        origin: wA,
        destination: wB,
      );

  setUp(() {
    mockRepo = MockTripSegmentRepository();
    useCase = ReorderTripSegmentsUseCase(mockRepo);
    when(() => mockRepo.reorderSegments(any(), any()))
        .thenAnswer((_) async => const Right(null));
  });

  test('renumbers a list with gaps to a dense 0..n-1 sequence', () async {
    final segments = [segment('a', 5), segment('b', 12), segment('c', 40)];

    await useCase('it-1', segments);

    final captured = verify(
      () => mockRepo.reorderSegments('it-1', captureAny()),
    ).captured;
    final reordered = captured.first as List<TripSegment>;

    expect(reordered.map((s) => s.orderIndex), [0, 1, 2]);
  });

  test('preserves the given order, not the original orderIndex order',
      () async {
    // Deliberately out of numeric order — the input order is what matters,
    // not each segment's stale orderIndex.
    final segments = [segment('a', 40), segment('b', 5), segment('c', 12)];

    await useCase('it-1', segments);

    final captured = verify(
      () => mockRepo.reorderSegments('it-1', captureAny()),
    ).captured;
    final reordered = captured.first as List<TripSegment>;

    expect(reordered.map((s) => s.id), ['a', 'b', 'c']);
    expect(reordered.map((s) => s.orderIndex), [0, 1, 2]);
  });

  test('does not mutate any other field on the segments', () async {
    final segments = [
      const TripSegment(
        id: 'a',
        itineraryId: 'it-1',
        orderIndex: 9,
        mode: TransportMode.motorcycle,
        origin: wB,
        destination: wC,
        notes: 'rented from the airport',
      ),
    ];

    await useCase('it-1', segments);

    final captured = verify(
      () => mockRepo.reorderSegments('it-1', captureAny()),
    ).captured;
    final reordered = captured.first as List<TripSegment>;

    expect(reordered.single.mode, TransportMode.motorcycle);
    expect(reordered.single.origin, wB);
    expect(reordered.single.destination, wC);
    expect(reordered.single.notes, 'rented from the airport');
    expect(reordered.single.orderIndex, 0);
  });

  test('handles an empty list', () async {
    await useCase('it-1', []);

    verify(() => mockRepo.reorderSegments('it-1', [])).called(1);
  });

  test('handles deletion (a shorter list than before) with no gaps left',
      () async {
    // Simulates deleting the middle segment of a 3-segment trip: the
    // remaining two are renumbered 0, 1 with no gap at the old index 1.
    final remaining = [segment('a', 0), segment('c', 2)];

    await useCase('it-1', remaining);

    final captured = verify(
      () => mockRepo.reorderSegments('it-1', captureAny()),
    ).captured;
    final reordered = captured.first as List<TripSegment>;

    expect(reordered.map((s) => s.orderIndex), [0, 1]);
  });

  test('returns Right(null) on success', () async {
    final result = await useCase('it-1', [segment('a', 0)]);

    expect(result.isRight(), isTrue);
  });

  test('propagates ServerFailure from repository', () async {
    when(() => mockRepo.reorderSegments(any(), any()))
        .thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('it-1', [segment('a', 0)]);

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
