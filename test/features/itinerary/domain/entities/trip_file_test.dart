import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_file.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';

const _summary = ExpenseSummary(
  totalSpent: 500,
  spentByCategory: {'flights': 500},
  memberBalances: {'user-1': 0},
);

TravelItinerary _itinerary() => TravelItinerary(
  id: 'trip-1',
  title: 'Tokyo Summer',
  description: 'A week in Tokyo',
  ownerId: 'user-1',
  startDate: DateTime.utc(2026, 6, 10),
  endDate: DateTime.utc(2026, 6, 17),
  totalBudget: 5000,
  currencyCode: 'USD',
  members: [
    GroupMember(
      userId: 'user-1',
      userName: 'Alice',
      role: GroupMemberRole.owner,
      joinedAt: DateTime.utc(2026),
    ),
  ],
  items: [
    ItineraryItem(
      id: 'item-1',
      itemType: 'activity',
      title: 'Senso-ji Temple',
      startTime: DateTime.utc(2026, 6, 11, 9),
      location: 'Asakusa',
      latitude: 35.7148,
      longitude: 139.7967,
    ),
  ],
  expenseSummary: _summary,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  themeKey: 'sakura',
);

TripSegment _segment() => const TripSegment(
  id: 'seg-1',
  itineraryId: 'trip-1',
  orderIndex: 0,
  mode: TransportMode.flight,
  origin: Waypoint(name: 'Munich', latitude: 48.1351, longitude: 11.5820),
  destination: Waypoint(name: 'Tokyo', latitude: 35.6762, longitude: 139.6503),
  notes: 'Gate 12',
);

void main() {
  group('TripFile.fromItinerary', () {
    test('carries trip metadata and items, never members or budget', () {
      final file = TripFile.fromItinerary(
        itinerary: _itinerary(),
        segments: [TripFileSegment.fromEntity(_segment())],
      );

      expect(file.title, 'Tokyo Summer');
      expect(file.description, 'A week in Tokyo');
      expect(file.currencyCode, 'USD');
      expect(file.themeKey, 'sakura');
      expect(file.items, hasLength(1));
      expect(file.segments, hasLength(1));
      // No members/budget/expenses field exists on TripFile at all — this
      // spot-checks the JSON output doesn't leak them either.
      expect(file.toJson().containsKey('members'), isFalse);
      expect(file.toJson().containsKey('total_budget'), isFalse);
      expect(file.toJson().containsKey('expense_summary'), isFalse);
    });
  });

  group('toJson/fromJson roundtrip', () {
    test('preserves trip metadata, items, and segments', () {
      final original = TripFile.fromItinerary(
        itinerary: _itinerary(),
        segments: [TripFileSegment.fromEntity(_segment())],
      );

      final roundTripped = TripFile.fromJson(original.toJson());

      expect(roundTripped.title, original.title);
      expect(roundTripped.description, original.description);
      expect(roundTripped.startDate, original.startDate);
      expect(roundTripped.endDate, original.endDate);
      expect(roundTripped.currencyCode, original.currencyCode);
      expect(roundTripped.themeKey, original.themeKey);
      expect(roundTripped.items.single.title, 'Senso-ji Temple');
      expect(roundTripped.items.single.latitude, 35.7148);
      expect(roundTripped.segments.single.origin.name, 'Munich');
      expect(roundTripped.segments.single.destination.name, 'Tokyo');
      expect(roundTripped.segments.single.mode, TransportMode.flight);
      expect(roundTripped.segments.single.notes, 'Gate 12');
    });

    test('assigns each imported item a fresh, non-empty id', () {
      final original = TripFile.fromItinerary(
        itinerary: _itinerary(),
        segments: const [],
      );

      final roundTripped = TripFile.fromJson(original.toJson());

      expect(roundTripped.items.single.id, isNotEmpty);
    });
  });

  group('TripFile.fromJson validation', () {
    test('rejects a file with no version marker', () {
      expect(
        () => TripFile.fromJson(const {'title': 'x'}),
        throwsFormatException,
      );
    });

    test('rejects a file exported by a newer app version', () {
      expect(
        () => TripFile.fromJson({
          'kumo_trip_file_version': TripFile.currentVersion + 1,
          'title': 'x',
          'start_date': DateTime.utc(2026).toIso8601String(),
          'end_date': DateTime.utc(2026, 1, 2).toIso8601String(),
          'currency_code': 'USD',
        }),
        throwsFormatException,
      );
    });

    test('rejects a file missing required fields', () {
      expect(
        () => TripFile.fromJson(const {'kumo_trip_file_version': 1}),
        throwsFormatException,
      );
    });

    test('defaults themeKey to classic and items/segments to empty', () {
      final file = TripFile.fromJson({
        'kumo_trip_file_version': TripFile.currentVersion,
        'title': 'Minimal trip',
        'start_date': DateTime.utc(2026).toIso8601String(),
        'end_date': DateTime.utc(2026, 1, 2).toIso8601String(),
        'currency_code': 'USD',
      });

      expect(file.themeKey, 'classic');
      expect(file.items, isEmpty);
      expect(file.segments, isEmpty);
    });
  });
}
