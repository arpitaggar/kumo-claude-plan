import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/geocoding/geocoding_providers.dart';
import 'package:kumo_claude/core/geocoding/geocoding_service.dart';
import 'package:kumo_claude/features/ai_generation/domain/entities/ai_generated_segment.dart';
import 'package:kumo_claude/features/ai_generation/presentation/providers/ai_generation_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/add_trip_segment_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/trip_segment_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockGeocodingService extends Mock implements GeocodingService {}

class MockAddTripSegmentUseCase extends Mock implements AddTripSegmentUseCase {}

void main() {
  late MockGeocodingService geocoder;
  late MockAddTripSegmentUseCase addSegment;
  late ProviderContainer container;

  const tResult = TripSegment(
    id: 'seg-1',
    itineraryId: 'it-1',
    orderIndex: 0,
    mode: TransportMode.flight,
    origin: Waypoint(name: 'x', latitude: 0, longitude: 0),
    destination: Waypoint(name: 'y', latitude: 0, longitude: 0),
  );

  setUpAll(() {
    registerFallbackValue(TransportMode.other);
    registerFallbackValue(
        const Waypoint(name: 'fallback', latitude: 0, longitude: 0));
    registerFallbackValue(DateTime(2000));
  });

  setUp(() {
    geocoder = MockGeocodingService();
    addSegment = MockAddTripSegmentUseCase();

    when(() => addSegment.call(
          itineraryId: any(named: 'itineraryId'),
          orderIndex: any(named: 'orderIndex'),
          mode: any(named: 'mode'),
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          departureTime: any(named: 'departureTime'),
          arrivalTime: any(named: 'arrivalTime'),
        )).thenAnswer((_) async => const Right(tResult));

    container = ProviderContainer(overrides: [
      geocodingServiceProvider.overrideWithValue(geocoder),
      addTripSegmentUseCaseProvider.overrideWithValue(addSegment),
    ]);
  });

  tearDown(() => container.dispose());

  test('geocodes each leg and inserts a resolved segment in order', () async {
    when(() => geocoder.search('Munich')).thenAnswer((_) async => const [
          GeocodingResult(
              name: 'Munich, Germany', latitude: 48.1351, longitude: 11.5820),
        ]);
    when(() => geocoder.search('Bangkok')).thenAnswer((_) async => const [
          GeocodingResult(
              name: 'Bangkok, Thailand',
              latitude: 13.7563,
              longitude: 100.5018),
        ]);

    final resolve = container.read(resolveAiSegmentsProvider);
    await resolve('it-1', const [
      AiGeneratedSegment(
        mode: TransportMode.flight,
        originName: 'Munich',
        destinationName: 'Bangkok',
      ),
    ]);

    final captured = verify(() => addSegment.call(
          itineraryId: 'it-1',
          orderIndex: 0,
          mode: TransportMode.flight,
          origin: captureAny(named: 'origin'),
          destination: captureAny(named: 'destination'),
        )).captured;

    expect((captured[0] as Waypoint).name, 'Munich, Germany');
    expect((captured[1] as Waypoint).name, 'Bangkok, Thailand');
  });

  test('numbers consecutive resolved legs 0, 1, 2, ...', () async {
    when(() => geocoder.search(any())).thenAnswer((_) async => const [
          GeocodingResult(name: 'Somewhere', latitude: 1, longitude: 2),
        ]);

    final resolve = container.read(resolveAiSegmentsProvider);
    await resolve('it-1', const [
      AiGeneratedSegment(
        mode: TransportMode.flight,
        originName: 'A',
        destinationName: 'B',
      ),
      AiGeneratedSegment(
        mode: TransportMode.motorcycle,
        originName: 'B',
        destinationName: 'C',
      ),
    ]);

    verify(() => addSegment.call(
          itineraryId: 'it-1',
          orderIndex: 0,
          mode: any(named: 'mode'),
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          departureTime: any(named: 'departureTime'),
          arrivalTime: any(named: 'arrivalTime'),
        )).called(1);
    verify(() => addSegment.call(
          itineraryId: 'it-1',
          orderIndex: 1,
          mode: any(named: 'mode'),
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          departureTime: any(named: 'departureTime'),
          arrivalTime: any(named: 'arrivalTime'),
        )).called(1);
  });

  test('skips a leg whose origin cannot be geocoded, without breaking the '
      'rest of the batch', () async {
    when(() => geocoder.search('Nowhere'))
        .thenAnswer((_) async => const []);
    when(() => geocoder.search('Bangkok')).thenAnswer((_) async => const [
          GeocodingResult(name: 'Bangkok', latitude: 13.7563, longitude: 100.5018),
        ]);
    when(() => geocoder.search('Chiang Mai')).thenAnswer((_) async => const [
          GeocodingResult(name: 'Chiang Mai', latitude: 18.7883, longitude: 98.9853),
        ]);

    final resolve = container.read(resolveAiSegmentsProvider);
    await resolve('it-1', const [
      AiGeneratedSegment(
        mode: TransportMode.flight,
        originName: 'Nowhere',
        destinationName: 'Bangkok',
      ),
      AiGeneratedSegment(
        mode: TransportMode.motorcycle,
        originName: 'Bangkok',
        destinationName: 'Chiang Mai',
      ),
    ]);

    // Only the second (fully-geocodable) leg gets inserted, and it still
    // lands at orderIndex 0 — the skipped leg doesn't leave a gap.
    verify(() => addSegment.call(
          itineraryId: 'it-1',
          orderIndex: 0,
          mode: TransportMode.motorcycle,
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          departureTime: any(named: 'departureTime'),
          arrivalTime: any(named: 'arrivalTime'),
        )).called(1);
    verifyNever(() => addSegment.call(
          itineraryId: 'it-1',
          orderIndex: any(named: 'orderIndex'),
          mode: TransportMode.flight,
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          departureTime: any(named: 'departureTime'),
          arrivalTime: any(named: 'arrivalTime'),
        ));
  });

  test('does nothing for an empty segment list', () async {
    final resolve = container.read(resolveAiSegmentsProvider);
    await resolve('it-1', const []);

    verifyNever(() => addSegment.call(
          itineraryId: any(named: 'itineraryId'),
          orderIndex: any(named: 'orderIndex'),
          mode: any(named: 'mode'),
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          departureTime: any(named: 'departureTime'),
          arrivalTime: any(named: 'arrivalTime'),
        ));
  });
}
