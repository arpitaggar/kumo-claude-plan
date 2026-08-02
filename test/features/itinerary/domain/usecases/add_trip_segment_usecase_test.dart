import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/trip_segment_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/add_trip_segment_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockTripSegmentRepository extends Mock implements TripSegmentRepository {}

class FakeTripSegment extends Fake implements TripSegment {}

void main() {
  late MockTripSegmentRepository mockRepo;
  late AddTripSegmentUseCase useCase;

  const tOrigin = Waypoint(name: 'Munich', latitude: 48.1351, longitude: 11.5820);
  const tDestination =
      Waypoint(name: 'Bangkok', latitude: 13.7563, longitude: 100.5018);

  setUpAll(() {
    registerFallbackValue(FakeTripSegment());
  });

  setUp(() {
    mockRepo = MockTripSegmentRepository();
    useCase = AddTripSegmentUseCase(mockRepo);
    when(() => mockRepo.addSegment(any())).thenAnswer(
      (invocation) async =>
          Right(invocation.positionalArguments[0] as TripSegment),
    );
  });

  group('AddTripSegmentUseCase', () {
    test('calls repository.addSegment once', () async {
      await useCase(
        itineraryId: 'it-1',
        orderIndex: 0,
        mode: TransportMode.flight,
        origin: tOrigin,
        destination: tDestination,
      );

      verify(() => mockRepo.addSegment(any())).called(1);
    });

    test('builds a segment with the given fields', () async {
      await useCase(
        itineraryId: 'it-1',
        orderIndex: 2,
        mode: TransportMode.motorcycle,
        origin: tOrigin,
        destination: tDestination,
        notes: 'rental booked',
      );

      final captured =
          verify(() => mockRepo.addSegment(captureAny())).captured;
      final segment = captured.first as TripSegment;

      expect(segment.itineraryId, 'it-1');
      expect(segment.orderIndex, 2);
      expect(segment.mode, TransportMode.motorcycle);
      expect(segment.origin, tOrigin);
      expect(segment.destination, tDestination);
      expect(segment.notes, 'rental booked');
    });

    test('segment id is a non-empty UUID string', () async {
      await useCase(
        itineraryId: 'it-1',
        orderIndex: 0,
        mode: TransportMode.flight,
        origin: tOrigin,
        destination: tDestination,
      );

      final captured =
          verify(() => mockRepo.addSegment(captureAny())).captured;
      final segment = captured.first as TripSegment;
      expect(segment.id, isNotEmpty);
      expect(segment.id.length, 36);
    });

    test('returns Right(segment) on success', () async {
      final result = await useCase(
        itineraryId: 'it-1',
        orderIndex: 0,
        mode: TransportMode.flight,
        origin: tOrigin,
        destination: tDestination,
      );

      expect(result.isRight(), isTrue);
    });

    test('propagates ServerFailure from repository', () async {
      when(() => mockRepo.addSegment(any()))
          .thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await useCase(
        itineraryId: 'it-1',
        orderIndex: 0,
        mode: TransportMode.flight,
        origin: tOrigin,
        destination: tDestination,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
