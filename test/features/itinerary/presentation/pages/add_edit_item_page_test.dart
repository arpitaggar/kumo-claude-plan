import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/config/constants.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/update_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/pages/add_edit_item_page.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockUpdateItineraryUseCase extends Mock
    implements UpdateItineraryUseCase {}

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip({List<ItineraryItem> items = const []}) =>
    TravelItinerary(
      id: 'trip-1',
      title: 'Test Trip',
      ownerId: 'user-1',
      startDate: DateTime.utc(2026, 6),
      endDate: DateTime.utc(2026, 6, 7),
      totalBudget: 500,
      currencyCode: AppConstants.defaultCurrency,
      members: const [],
      items: items,
      expenseSummary: _summary,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

Future<MockUpdateItineraryUseCase> _pump(
  WidgetTester tester, {
  required TravelItinerary itinerary,
  String? itemId,
  AddItemPrefill? prefill,
  Either<Failure, TravelItinerary>? submitResult,
}) async {
  final updateUseCase = MockUpdateItineraryUseCase();
  when(
    () => updateUseCase(any()),
  ).thenAnswer((_) async => submitResult ?? Right(itinerary));

  final overrides = <Override>[
    itineraryStreamProvider(
      itinerary.id,
    ).overrideWith((ref) => Stream.value(itinerary)),
    updateItineraryUseCaseProvider.overrideWithValue(updateUseCase),
  ];

  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: '/add-edit-item',
        builder: (_, _) => AddEditItemPage(
          itineraryId: itinerary.id,
          itemId: itemId,
          prefill: prefill,
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // ignore: unawaited_futures
  router.push('/add-edit-item');
  await tester.pumpAndSettle();
  return updateUseCase;
}

Future<void> _pickStart(WidgetTester tester) async {
  final startField = find.ancestor(
    of: find.text('Start'),
    matching: find.byType(InkWell),
  );
  await tester.tap(startField);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_trip());
  });
  setUpAll(initTestSupabase);

  testWidgets('add mode shows the Add Activity title and an empty form', (
    tester,
  ) async {
    await _pump(tester, itinerary: _trip());

    expect(find.text('Add Activity'), findsWidgets);
    expect(find.text('Edit Activity'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Activity name'), findsOneWidget);
  });

  testWidgets('edit mode pre-fills the form from the existing item', (
    tester,
  ) async {
    final item = ItineraryItem(
      id: 'item-1',
      itemType: 'restaurant',
      title: 'Ramen Ichiban',
      startTime: DateTime.utc(2026, 6, 2, 12),
      location: 'Shibuya',
    );
    await _pump(
      tester,
      itinerary: _trip(items: [item]),
      itemId: 'item-1',
    );

    expect(find.text('Edit Activity'), findsWidgets);
    expect(find.text('Ramen Ichiban'), findsOneWidget);
    expect(find.text('Shibuya'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('submit is blocked without a name', (tester) async {
    final updateUseCase = await _pump(tester, itinerary: _trip());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    verifyNever(() => updateUseCase(any()));
  });

  testWidgets('submit is blocked without a start date/time', (tester) async {
    final updateUseCase = await _pump(tester, itinerary: _trip());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Activity name'),
      'Senso-ji Temple',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Please select a start date and time'), findsOneWidget);
    verifyNever(() => updateUseCase(any()));
  });

  testWidgets(
    'adding a new item appends it to the itinerary and calls UpdateItineraryUseCase',
    (tester) async {
      final updateUseCase = await _pump(tester, itinerary: _trip());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Activity name'),
        'Senso-ji Temple',
      );
      await _pickStart(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Activity'));
      await tester.pumpAndSettle();

      final captured = verify(() => updateUseCase(captureAny())).captured;
      final updated = captured.single as TravelItinerary;
      expect(updated.items, hasLength(1));
      expect(updated.items.single.title, 'Senso-ji Temple');
    },
  );

  testWidgets(
    'editing an existing item replaces it in place, keeping the same id',
    (tester) async {
      final item = ItineraryItem(
        id: 'item-1',
        itemType: 'restaurant',
        title: 'Ramen Ichiban',
        startTime: DateTime.utc(2026, 6, 2, 12),
      );
      final updateUseCase = await _pump(
        tester,
        itinerary: _trip(items: [item]),
        itemId: 'item-1',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Activity name'),
        'Ramen Jiro',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      final captured = verify(() => updateUseCase(captureAny())).captured;
      final updated = captured.single as TravelItinerary;
      expect(updated.items, hasLength(1));
      expect(updated.items.single.id, 'item-1');
      expect(updated.items.single.title, 'Ramen Jiro');
    },
  );

  testWidgets('shows a snackbar when the update usecase fails', (tester) async {
    await _pump(
      tester,
      itinerary: _trip(),
      submitResult: const Left(ServerFailure('Could not save activity')),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Activity name'),
      'Senso-ji Temple',
    );
    await _pickStart(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save activity'), findsOneWidget);
  });

  testWidgets(
    'a booking prefill shows "Confirm Booking" and pre-fills name/location, '
    'with the booked switch already on',
    (tester) async {
      await _pump(
        tester,
        itinerary: _trip(),
        prefill: AddItemPrefill(
          title: 'Grand Plaza Hotel',
          itemType: 'hotel',
          location: 'Grand Plaza Hotel',
          latitude: 45.44,
          longitude: 12.31,
          startTime: DateTime.utc(2026, 6, 10, 15),
          endTime: DateTime.utc(2026, 6, 15, 11),
          isBooked: true,
          bookingListingKey: 'expedia:listing-42',
        ),
      );

      expect(find.text('Confirm Booking'), findsWidgets);
      expect(find.text('Grand Plaza Hotel'), findsWidgets);
      expect(find.text('Save Booking'), findsOneWidget);

      final bookedSwitch = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(bookedSwitch.value, isTrue);
    },
  );

  testWidgets('submitting a booking prefill carries isBooked/bookingListingKey/'
      'coordinates through to the saved item', (tester) async {
    final trip = _trip();
    final updateUseCase = await _pump(
      tester,
      itinerary: trip,
      prefill: AddItemPrefill(
        title: 'Grand Plaza Hotel',
        itemType: 'hotel',
        location: 'Grand Plaza Hotel',
        latitude: 45.44,
        longitude: 12.31,
        startTime: DateTime.utc(2026, 6, 10, 15),
        endTime: DateTime.utc(2026, 6, 15, 11),
        isBooked: true,
        bookingListingKey: 'expedia:listing-42',
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Booking'));
    await tester.pumpAndSettle();

    final captured = verify(() => updateUseCase(captureAny())).captured;
    final updated = captured.single as TravelItinerary;
    final saved = updated.items.single;
    expect(saved.title, 'Grand Plaza Hotel');
    expect(saved.isBooked, isTrue);
    expect(saved.bookingListingKey, 'expedia:listing-42');
    expect(saved.latitude, 45.44);
    expect(saved.longitude, 12.31);
  });

  testWidgets(
    'manually toggling "Mark as booked" on a plain new activity persists '
    'isBooked without a bookingListingKey',
    (tester) async {
      final updateUseCase = await _pump(tester, itinerary: _trip());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Activity name'),
        'Senso-ji Temple',
      );
      await _pickStart(tester);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Booking'));
      await tester.pumpAndSettle();

      final captured = verify(() => updateUseCase(captureAny())).captured;
      final saved = (captured.single as TravelItinerary).items.single;
      expect(saved.isBooked, isTrue);
      expect(saved.bookingListingKey, isNull);
    },
  );

  testWidgets(
    'editing an already-booked item shows the switch on and keeps its '
    'bookingListingKey when saved without re-toggling',
    (tester) async {
      final item = ItineraryItem(
        id: 'item-1',
        itemType: 'hotel',
        title: 'Grand Plaza Hotel',
        startTime: DateTime.utc(2026, 6, 10, 15),
        endTime: DateTime.utc(2026, 6, 15, 11),
        location: 'Grand Plaza Hotel',
        latitude: 45.44,
        longitude: 12.31,
        isBooked: true,
        bookingListingKey: 'expedia:expedia-0',
      );
      final updateUseCase = await _pump(
        tester,
        itinerary: _trip(items: [item]),
        itemId: 'item-1',
      );

      final bookedSwitch = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(bookedSwitch.value, isTrue);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      final captured = verify(() => updateUseCase(captureAny())).captured;
      final saved = (captured.single as TravelItinerary).items.single;
      expect(saved.isBooked, isTrue);
      expect(saved.bookingListingKey, 'expedia:expedia-0');
      expect(saved.latitude, 45.44);
      expect(saved.longitude, 12.31);
    },
  );

  testWidgets(
    'toggling "Mark as booked" off on an already-booked item persists '
    'isBooked: false',
    (tester) async {
      final item = ItineraryItem(
        id: 'item-1',
        itemType: 'hotel',
        title: 'Grand Plaza Hotel',
        startTime: DateTime.utc(2026, 6, 10, 15),
        isBooked: true,
        bookingListingKey: 'expedia:expedia-0',
      );
      final updateUseCase = await _pump(
        tester,
        itinerary: _trip(items: [item]),
        itemId: 'item-1',
      );

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      final captured = verify(() => updateUseCase(captureAny())).captured;
      final saved = (captured.single as TravelItinerary).items.single;
      expect(saved.isBooked, isFalse);
    },
  );
}
