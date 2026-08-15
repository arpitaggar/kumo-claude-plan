import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_file.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/add_trip_segment_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/create_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/import_trip_file_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateItineraryUseCase extends Mock
    implements CreateItineraryUseCase {}

class MockAddTripSegmentUseCase extends Mock implements AddTripSegmentUseCase {}

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _created() => TravelItinerary(
  id: 'new-trip',
  title: 'Tokyo Summer',
  ownerId: 'user-2',
  startDate: DateTime.utc(2026, 6, 10),
  endDate: DateTime.utc(2026, 6, 17),
  totalBudget: 0,
  currencyCode: 'USD',
  members: const [],
  items: const [],
  expenseSummary: _summary,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

TripFile _file({List<TripFileSegment> segments = const []}) => TripFile(
  title: 'Tokyo Summer',
  startDate: DateTime.utc(2026, 6, 10),
  endDate: DateTime.utc(2026, 6, 17),
  currencyCode: 'USD',
  themeKey: 'sakura',
  items: const [],
  segments: segments,
);

void main() {
  late MockCreateItineraryUseCase createUseCase;
  late MockAddTripSegmentUseCase addSegmentUseCase;
  late ImportTripFileUseCase useCase;

  setUpAll(() {
    registerFallbackValue(TransportMode.flight);
    registerFallbackValue(const Waypoint(name: 'x', latitude: 0, longitude: 0));
  });

  setUp(() {
    createUseCase = MockCreateItineraryUseCase();
    addSegmentUseCase = MockAddTripSegmentUseCase();
    useCase = ImportTripFileUseCase(createUseCase, addSegmentUseCase);
  });

  group('ImportTripFileUseCase', () {
    test(
      'creates a new itinerary with zero budget, owned by the importer',
      () async {
        when(
          () => createUseCase(
            title: any(named: 'title'),
            ownerId: any(named: 'ownerId'),
            ownerName: any(named: 'ownerName'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            totalBudget: any(named: 'totalBudget'),
            currencyCode: any(named: 'currencyCode'),
            description: any(named: 'description'),
            items: any(named: 'items'),
            themeKey: any(named: 'themeKey'),
          ),
        ).thenAnswer((_) async => Right(_created()));

        final result = await useCase(
          file: _file(),
          newOwnerId: 'user-2',
          newOwnerName: 'Bob',
        );

        expect(result, Right(_created()));
        verify(
          () => createUseCase(
            title: 'Tokyo Summer',
            ownerId: 'user-2',
            ownerName: 'Bob',
            startDate: DateTime.utc(2026, 6, 10),
            endDate: DateTime.utc(2026, 6, 17),
            totalBudget: 0,
            currencyCode: 'USD',
            items: const [],
            themeKey: 'sakura',
          ),
        ).called(1);
      },
    );

    test('adds each segment from the file to the new trip', () async {
      when(
        () => createUseCase(
          title: any(named: 'title'),
          ownerId: any(named: 'ownerId'),
          ownerName: any(named: 'ownerName'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          totalBudget: any(named: 'totalBudget'),
          currencyCode: any(named: 'currencyCode'),
          description: any(named: 'description'),
          items: any(named: 'items'),
          themeKey: any(named: 'themeKey'),
        ),
      ).thenAnswer((_) async => Right(_created()));
      when(
        () => addSegmentUseCase(
          itineraryId: any(named: 'itineraryId'),
          orderIndex: any(named: 'orderIndex'),
          mode: any(named: 'mode'),
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          departureTime: any(named: 'departureTime'),
          arrivalTime: any(named: 'arrivalTime'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer(
        (_) async => const Right(
          TripSegment(
            id: 'seg-new',
            itineraryId: 'new-trip',
            orderIndex: 0,
            mode: TransportMode.flight,
            origin: Waypoint(name: 'Munich', latitude: 48.13, longitude: 11.58),
            destination: Waypoint(
              name: 'Tokyo',
              latitude: 35.67,
              longitude: 139.65,
            ),
          ),
        ),
      );

      await useCase(
        file: _file(
          segments: const [
            TripFileSegment(
              orderIndex: 0,
              mode: TransportMode.flight,
              origin: Waypoint(
                name: 'Munich',
                latitude: 48.13,
                longitude: 11.58,
              ),
              destination: Waypoint(
                name: 'Tokyo',
                latitude: 35.67,
                longitude: 139.65,
              ),
            ),
          ],
        ),
        newOwnerId: 'user-2',
        newOwnerName: 'Bob',
      );

      verify(
        () => addSegmentUseCase(
          itineraryId: 'new-trip',
          orderIndex: 0,
          mode: TransportMode.flight,
          origin: const Waypoint(
            name: 'Munich',
            latitude: 48.13,
            longitude: 11.58,
          ),
          destination: const Waypoint(
            name: 'Tokyo',
            latitude: 35.67,
            longitude: 139.65,
          ),
        ),
      ).called(1);
    });

    test(
      'returns the failure and never adds segments when creation fails',
      () async {
        when(
          () => createUseCase(
            title: any(named: 'title'),
            ownerId: any(named: 'ownerId'),
            ownerName: any(named: 'ownerName'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            totalBudget: any(named: 'totalBudget'),
            currencyCode: any(named: 'currencyCode'),
            description: any(named: 'description'),
            items: any(named: 'items'),
            themeKey: any(named: 'themeKey'),
          ),
        ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

        final result = await useCase(
          file: _file(),
          newOwnerId: 'user-2',
          newOwnerName: 'Bob',
        );

        expect(
          result,
          const Left<Failure, TravelItinerary>(ServerFailure('DB error')),
        );
        verifyNever(
          () => addSegmentUseCase(
            itineraryId: any(named: 'itineraryId'),
            orderIndex: any(named: 'orderIndex'),
            mode: any(named: 'mode'),
            origin: any(named: 'origin'),
            destination: any(named: 'destination'),
          ),
        );
      },
    );
  });
}
