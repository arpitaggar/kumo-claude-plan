import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/chat/domain/entities/message.dart';
import 'package:kumo_claude/features/chat/presentation/providers/chat_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/create_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/delete_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_itineraries_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/update_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:mocktail/mocktail.dart';

// inboxLastVisitProvider/inboxHasUnreadProvider (chat_provider.dart) had no
// test coverage at all — found during a docs/test audit pass. Both
// kumo_shell.dart (the unread badge) and inbox_page.dart (which updates
// the last-visit timestamp) depend on inboxHasUnreadProvider's exact
// semantics, in particular the deliberate "0 means never-visited, not
// epoch-zero" choice this suite locks in.

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
  title: 'Trip $id',
  ownerId: 'user-1',
  startDate: DateTime(2026, 10),
  endDate: DateTime(2026, 10, 7),
  totalBudget: 1000,
  currencyCode: 'EUR',
  members: const [],
  items: const [],
  expenseSummary: _summary,
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
);

Message _msg({
  required String tripId,
  required String id,
  required DateTime createdAt,
}) => Message(
  id: id,
  itineraryId: tripId,
  senderId: 'someone',
  senderName: 'Someone',
  content: 'hi',
  createdAt: createdAt,
);

/// StreamProviders (chatStreamProvider) don't have a value until something
/// has actually listened and the stream has had a chance to emit — even a
/// synchronous Stream.value(...) override delivers on a microtask, not
/// immediately. Pin a listener on each trip's stream and let one event-loop
/// turn pass before reading inboxHasUnreadProvider, or its .value lookups
/// see AsyncLoading (null) and every trip is silently skipped.
Future<void> _settleStreams(
  ProviderContainer container,
  List<String> tripIds,
) async {
  for (final id in tripIds) {
    container.listen(chatStreamProvider(id), (_, _) {});
  }
  await Future<void>.delayed(Duration.zero);
}

Future<ProviderContainer> _harness({required List<String> tripIds}) async {
  final fetchUseCase = MockFetchItinerariesUseCase();
  when(
    () => fetchUseCase(any()),
  ).thenAnswer((_) async => Right(tripIds.map(_trip).toList()));
  final itineraryNotifier = ItineraryListNotifier(
    fetchUseCase: fetchUseCase,
    createUseCase: MockCreateItineraryUseCase(),
    updateUseCase: MockUpdateItineraryUseCase(),
    deleteUseCase: MockDeleteItineraryUseCase(),
  );

  final overrides = <Override>[
    itineraryListProvider.overrideWith((ref) => itineraryNotifier),
    for (final id in tripIds)
      chatStreamProvider(id).overrideWith((ref) => Stream.value(const [])),
  ];

  final container = ProviderContainer(overrides: overrides);
  await itineraryNotifier.loadItineraries('user-1');
  await _settleStreams(container, tripIds);
  return container;
}

void main() {
  group('inboxHasUnreadProvider', () {
    test('is false when the inbox has never been visited (lastVisit == 0), '
        'even with a brand-new message', () async {
      final container = ProviderContainer(
        overrides: [
          itineraryListProvider.overrideWith((ref) {
            final fetchUseCase = MockFetchItinerariesUseCase();
            when(
              () => fetchUseCase(any()),
            ).thenAnswer((_) async => Right([_trip('t1')]));
            return ItineraryListNotifier(
              fetchUseCase: fetchUseCase,
              createUseCase: MockCreateItineraryUseCase(),
              updateUseCase: MockUpdateItineraryUseCase(),
              deleteUseCase: MockDeleteItineraryUseCase(),
            );
          }),
          chatStreamProvider('t1').overrideWith(
            (ref) => Stream.value([
              _msg(tripId: 't1', id: 'm1', createdAt: DateTime.now()),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(itineraryListProvider.notifier)
          .loadItineraries('user-1');
      await _settleStreams(container, ['t1']);

      // inboxLastVisitProvider is left at its default (0) — deliberately
      // never set here, matching a fresh app session before InboxPage's
      // own SharedPreferences-backed initialization has run.
      expect(container.read(inboxHasUnreadProvider), isFalse);
    });

    test('is false when the itinerary list has not finished loading', () async {
      final fetchUseCase = MockFetchItinerariesUseCase();
      final completer = Completer<Either<Failure, List<TravelItinerary>>>();
      when(() => fetchUseCase(any())).thenAnswer((_) => completer.future);
      final notifier = ItineraryListNotifier(
        fetchUseCase: fetchUseCase,
        createUseCase: MockCreateItineraryUseCase(),
        updateUseCase: MockUpdateItineraryUseCase(),
        deleteUseCase: MockDeleteItineraryUseCase(),
      );
      final container = ProviderContainer(
        overrides: [itineraryListProvider.overrideWith((ref) => notifier)],
      );
      addTearDown(container.dispose);

      final unawaited = notifier.loadItineraries('user-1');
      container.read(inboxLastVisitProvider.notifier).state = 1000;

      expect(container.read(inboxHasUnreadProvider), isFalse);

      // Let the pending load settle so the test doesn't leak a dangling
      // Future/timer into the next test.
      completer.complete(const Right([]));
      await unawaited;
    });

    test('is false when no trip has a message newer than lastVisit', () async {
      final container = await _harness(tripIds: ['t1', 't2']);
      addTearDown(container.dispose);
      container.read(inboxLastVisitProvider.notifier).state = 1000;

      expect(container.read(inboxHasUnreadProvider), isFalse);
    });

    test('is true when a trip has a message newer than lastVisit', () async {
      final container = ProviderContainer(
        overrides: [
          itineraryListProvider.overrideWith((ref) {
            final fetchUseCase = MockFetchItinerariesUseCase();
            when(
              () => fetchUseCase(any()),
            ).thenAnswer((_) async => Right([_trip('t1')]));
            return ItineraryListNotifier(
              fetchUseCase: fetchUseCase,
              createUseCase: MockCreateItineraryUseCase(),
              updateUseCase: MockUpdateItineraryUseCase(),
              deleteUseCase: MockDeleteItineraryUseCase(),
            );
          }),
          chatStreamProvider('t1').overrideWith(
            (ref) => Stream.value([
              _msg(
                tripId: 't1',
                id: 'm1',
                createdAt: DateTime.fromMillisecondsSinceEpoch(5000),
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(itineraryListProvider.notifier)
          .loadItineraries('user-1');
      await _settleStreams(container, ['t1']);
      container.read(inboxLastVisitProvider.notifier).state = 1000;

      expect(container.read(inboxHasUnreadProvider), isTrue);
    });

    test('only the latest message in a trip\'s stream is considered', () async {
      final container = ProviderContainer(
        overrides: [
          itineraryListProvider.overrideWith((ref) {
            final fetchUseCase = MockFetchItinerariesUseCase();
            when(
              () => fetchUseCase(any()),
            ).thenAnswer((_) async => Right([_trip('t1')]));
            return ItineraryListNotifier(
              fetchUseCase: fetchUseCase,
              createUseCase: MockCreateItineraryUseCase(),
              updateUseCase: MockUpdateItineraryUseCase(),
              deleteUseCase: MockDeleteItineraryUseCase(),
            );
          }),
          // Newest message (last in the list) is older than lastVisit, even
          // though an earlier message in the same list is newer — the
          // provider must key off .last, not any earlier entry.
          chatStreamProvider('t1').overrideWith(
            (ref) => Stream.value([
              _msg(
                tripId: 't1',
                id: 'm1',
                createdAt: DateTime.fromMillisecondsSinceEpoch(9000),
              ),
              _msg(
                tripId: 't1',
                id: 'm2',
                createdAt: DateTime.fromMillisecondsSinceEpoch(500),
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(itineraryListProvider.notifier)
          .loadItineraries('user-1');
      await _settleStreams(container, ['t1']);
      container.read(inboxLastVisitProvider.notifier).state = 1000;

      expect(container.read(inboxHasUnreadProvider), isFalse);
    });

    test('checks every trip, not just the first', () async {
      final container = ProviderContainer(
        overrides: [
          itineraryListProvider.overrideWith((ref) {
            final fetchUseCase = MockFetchItinerariesUseCase();
            when(
              () => fetchUseCase(any()),
            ).thenAnswer((_) async => Right([_trip('t1'), _trip('t2')]));
            return ItineraryListNotifier(
              fetchUseCase: fetchUseCase,
              createUseCase: MockCreateItineraryUseCase(),
              updateUseCase: MockUpdateItineraryUseCase(),
              deleteUseCase: MockDeleteItineraryUseCase(),
            );
          }),
          chatStreamProvider(
            't1',
          ).overrideWith((ref) => Stream.value(const [])),
          chatStreamProvider('t2').overrideWith(
            (ref) => Stream.value([
              _msg(
                tripId: 't2',
                id: 'm1',
                createdAt: DateTime.fromMillisecondsSinceEpoch(5000),
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(itineraryListProvider.notifier)
          .loadItineraries('user-1');
      await _settleStreams(container, ['t1', 't2']);
      container.read(inboxLastVisitProvider.notifier).state = 1000;

      expect(container.read(inboxHasUnreadProvider), isTrue);
    });
  });
}
