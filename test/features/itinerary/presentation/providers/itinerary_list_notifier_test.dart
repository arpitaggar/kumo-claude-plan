import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/create_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/delete_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_itineraries_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/update_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockFetchItinerariesUseCase extends Mock
    implements FetchItinerariesUseCase {}

class MockCreateItineraryUseCase extends Mock
    implements CreateItineraryUseCase {}

class MockUpdateItineraryUseCase extends Mock
    implements UpdateItineraryUseCase {}

class MockDeleteItineraryUseCase extends Mock
    implements DeleteItineraryUseCase {}

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip(String id) => TravelItinerary(
  id: id,
  title: id,
  ownerId: 'user-1',
  startDate: DateTime.utc(2026, 6),
  endDate: DateTime.utc(2026, 6, 7),
  totalBudget: 1000,
  currencyCode: 'USD',
  members: const [],
  items: const [],
  expenseSummary: _summary,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late MockFetchItinerariesUseCase fetchUseCase;
  late MockCreateItineraryUseCase createUseCase;
  late MockUpdateItineraryUseCase updateUseCase;
  late MockDeleteItineraryUseCase deleteUseCase;
  late ItineraryListNotifier notifier;

  setUp(() {
    fetchUseCase = MockFetchItinerariesUseCase();
    createUseCase = MockCreateItineraryUseCase();
    updateUseCase = MockUpdateItineraryUseCase();
    deleteUseCase = MockDeleteItineraryUseCase();
    notifier = ItineraryListNotifier(
      fetchUseCase: fetchUseCase,
      createUseCase: createUseCase,
      updateUseCase: updateUseCase,
      deleteUseCase: deleteUseCase,
    );
  });

  test('starts in ItineraryListInitial', () {
    expect(notifier.state, isA<ItineraryListInitial>());
  });

  group('loadItineraries', () {
    test('transitions Loading -> Loaded on success', () async {
      when(
        () => fetchUseCase('user-1'),
      ).thenAnswer((_) async => Right([_trip('trip-1')]));

      final future = notifier.loadItineraries('user-1');
      expect(notifier.state, isA<ItineraryListLoading>());
      await future;

      final state = notifier.state;
      expect(state, isA<ItineraryListLoaded>());
      expect((state as ItineraryListLoaded).itineraries, hasLength(1));
    });

    test('transitions Loading -> Error on failure', () async {
      when(
        () => fetchUseCase('user-1'),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      await notifier.loadItineraries('user-1');

      final state = notifier.state;
      expect(state, isA<ItineraryListError>());
      expect((state as ItineraryListError).message, 'DB error');
    });

    test('catches a thrown exception into ItineraryListError', () async {
      when(() => fetchUseCase('user-1')).thenThrow(Exception('boom'));

      await notifier.loadItineraries('user-1');

      expect(notifier.state, isA<ItineraryListError>());
    });
  });

  group('softRefresh', () {
    test(
      'updates state to Loaded without an intermediate Loading state',
      () async {
        when(
          () => fetchUseCase('user-1'),
        ).thenAnswer((_) async => Right([_trip('trip-1')]));

        final future = notifier.softRefresh('user-1');
        // No loading state emitted — still initial until the fetch resolves.
        expect(notifier.state, isA<ItineraryListInitial>());
        await future;

        expect(notifier.state, isA<ItineraryListLoaded>());
      },
    );

    test('silently keeps the current state on failure', () async {
      when(
        () => fetchUseCase('user-1'),
      ).thenAnswer((_) async => Right([_trip('trip-1')]));
      await notifier.loadItineraries('user-1');

      when(
        () => fetchUseCase('user-1'),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));
      await notifier.softRefresh('user-1');

      // Still showing the previously-loaded list, not an error state.
      final state = notifier.state;
      expect(state, isA<ItineraryListLoaded>());
      expect((state as ItineraryListLoaded).itineraries, hasLength(1));
    });

    test('silently swallows a thrown exception', () async {
      when(() => fetchUseCase('user-1')).thenThrow(Exception('boom'));

      await notifier.softRefresh('user-1');

      expect(notifier.state, isA<ItineraryListInitial>());
    });
  });

  group('createItinerary', () {
    test(
      'prepends the new trip to an already-loaded list and returns it',
      () async {
        when(
          () => fetchUseCase('user-1'),
        ).thenAnswer((_) async => Right([_trip('existing')]));
        await notifier.loadItineraries('user-1');

        final created = _trip('new-trip');
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
            orgId: any(named: 'orgId'),
          ),
        ).thenAnswer((_) async => Right(created));

        final result = await notifier.createItinerary(
          title: 'New Trip',
          ownerId: 'user-1',
          ownerName: 'Alice',
          startDate: DateTime.utc(2026, 7),
          endDate: DateTime.utc(2026, 7, 5),
          totalBudget: 500,
          currencyCode: 'USD',
        );

        expect(result, created);
        final state = notifier.state;
        expect(state, isA<ItineraryListLoaded>());
        expect((state as ItineraryListLoaded).itineraries.map((t) => t.id), [
          'new-trip',
          'existing',
        ]);
      },
    );

    test('starts a fresh list when nothing was loaded yet', () async {
      final created = _trip('first-trip');
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
          orgId: any(named: 'orgId'),
        ),
      ).thenAnswer((_) async => Right(created));

      final result = await notifier.createItinerary(
        title: 'First Trip',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: DateTime.utc(2026, 7),
        endDate: DateTime.utc(2026, 7, 5),
        totalBudget: 500,
        currencyCode: 'USD',
      );

      expect(result, created);
      final state = notifier.state;
      expect((state as ItineraryListLoaded).itineraries, [created]);
    });

    test('sets ItineraryListError and returns null on failure', () async {
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
          orgId: any(named: 'orgId'),
        ),
      ).thenAnswer((_) async => const Left(ValidationFailure('Bad title')));

      final result = await notifier.createItinerary(
        title: '',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: DateTime.utc(2026, 7),
        endDate: DateTime.utc(2026, 7, 5),
        totalBudget: 500,
        currencyCode: 'USD',
      );

      expect(result, isNull);
      final state = notifier.state;
      expect(state, isA<ItineraryListError>());
      expect((state as ItineraryListError).message, 'Bad title');
    });
  });

  group('deleteItinerary', () {
    test('removes the trip from an already-loaded list on success', () async {
      when(
        () => fetchUseCase('user-1'),
      ).thenAnswer((_) async => Right([_trip('keep'), _trip('remove')]));
      await notifier.loadItineraries('user-1');
      when(
        () => deleteUseCase('remove'),
      ).thenAnswer((_) async => const Right(null));

      await notifier.deleteItinerary('remove');

      final state = notifier.state;
      expect(state, isA<ItineraryListLoaded>());
      expect((state as ItineraryListLoaded).itineraries.map((t) => t.id), [
        'keep',
      ]);
    });

    test('sets ItineraryListError on failure', () async {
      when(
        () => deleteUseCase('trip-1'),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      await notifier.deleteItinerary('trip-1');

      expect(notifier.state, isA<ItineraryListError>());
    });
  });
}
