import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/ai_generation/data/datasources/ai_generation_datasource.dart';

void main() {
  final tripStart = DateTime.utc(2026, 6, 10);

  group('AiGenerationDataSourceImpl.parseItems', () {
    test('parses a valid item list', () {
      final raw = [
        {
          'item_type': 'activity',
          'title': 'Visit Senso-ji Temple',
          'start_time': '2026-06-10T09:00:00Z',
          'end_time': '2026-06-10T11:00:00Z',
          'location': 'Asakusa, Tokyo',
        },
        {
          'item_type': 'restaurant',
          'title': 'Ramen lunch',
          'start_time': '2026-06-10T12:30:00Z',
          'end_time': null,
          'location': null,
        },
      ];

      final items = AiGenerationDataSourceImpl.parseItems(raw, tripStart);

      expect(items, hasLength(2));
      expect(items[0].title, 'Visit Senso-ji Temple');
      expect(items[0].itemType, 'activity');
      expect(items[0].location, 'Asakusa, Tokyo');
      expect(items[1].title, 'Ramen lunch');
      expect(items[1].location, isNull);
      expect(items[1].endTime, isNull);
    });

    test('items are sorted by startTime ascending', () {
      final raw = [
        {
          'item_type': 'activity',
          'title': 'Evening walk',
          'start_time': '2026-06-10T19:00:00Z',
          'end_time': null,
          'location': null,
        },
        {
          'item_type': 'activity',
          'title': 'Morning yoga',
          'start_time': '2026-06-10T07:00:00Z',
          'end_time': null,
          'location': null,
        },
      ];

      final items = AiGenerationDataSourceImpl.parseItems(raw, tripStart);

      expect(items[0].title, 'Morning yoga');
      expect(items[1].title, 'Evening walk');
    });

    test('falls back to tripStart when start_time is null', () {
      final raw = [
        {
          'item_type': 'activity',
          'title': 'Free time',
          'start_time': null,
          'end_time': null,
          'location': null,
        },
      ];

      final items = AiGenerationDataSourceImpl.parseItems(raw, tripStart);

      expect(items[0].startTime, tripStart.toUtc());
    });

    test('falls back to tripStart when start_time is unparseable', () {
      final raw = [
        {
          'item_type': 'activity',
          'title': 'Mystery event',
          'start_time': 'not-a-date',
          'end_time': null,
          'location': null,
        },
      ];

      final items = AiGenerationDataSourceImpl.parseItems(raw, tripStart);

      expect(items[0].startTime, tripStart.toUtc());
    });

    test('ignores unparseable end_time', () {
      final raw = [
        {
          'item_type': 'hotel',
          'title': 'Hotel check-in',
          'start_time': '2026-06-10T15:00:00Z',
          'end_time': 'bad-date',
          'location': 'Shinjuku',
        },
      ];

      final items = AiGenerationDataSourceImpl.parseItems(raw, tripStart);

      expect(items[0].endTime, isNull);
    });

    test('each item gets a unique non-empty id', () {
      final raw = List.generate(
        3,
        (i) => {
          'item_type': 'activity',
          'title': 'Item $i',
          'start_time': '2026-06-10T0${i + 9}:00:00Z',
          'end_time': null,
          'location': null,
        },
      );

      final items = AiGenerationDataSourceImpl.parseItems(raw, tripStart);
      final ids = items.map((e) => e.id).toSet();

      expect(ids, hasLength(3));
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });

    test('uses activity as default when item_type is missing', () {
      final raw = [
        {
          'title': 'Mystery stop',
          'start_time': '2026-06-10T10:00:00Z',
          'end_time': null,
          'location': null,
        },
      ];

      final items = AiGenerationDataSourceImpl.parseItems(raw, tripStart);

      expect(items[0].itemType, 'activity');
    });

    test('uses Untitled as default when title is missing', () {
      final raw = [
        {
          'item_type': 'activity',
          'start_time': '2026-06-10T10:00:00Z',
          'end_time': null,
          'location': null,
        },
      ];

      final items = AiGenerationDataSourceImpl.parseItems(raw, tripStart);

      expect(items[0].title, 'Untitled');
    });

    test('returns empty list for empty input', () {
      final items = AiGenerationDataSourceImpl.parseItems([], tripStart);
      expect(items, isEmpty);
    });
  });
}
