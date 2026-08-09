import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/social/data/models/itinerary_post_model.dart';

void main() {
  final tItem = ItineraryItem(
    id: 'item-1',
    itemType: 'activity',
    title: 'Visit Senso-ji',
    startTime: DateTime.utc(2026, 6, 1, 9),
  );

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

  final fullJson = <String, dynamic>{
    'id': 'post-1',
    'source_itinerary_id': 'it-1',
    'author_id': 'user-1',
    'author_name': 'Alice',
    'author_avatar_url': 'https://example.com/a.png',
    'forked_from_post_id': 'post-0',
    'title': 'Tokyo Summer 2026',
    'description': 'A week in Tokyo',
    'start_date': '2026-06-01T00:00:00.000Z',
    'end_date': '2026-06-07T00:00:00.000Z',
    'theme_key': 'sakura',
    'currency_code': 'JPY',
    'like_count': 4,
    'created_at': '2026-06-10T00:00:00.000Z',
    'snapshot': {
      'items': [
        {
          'id': 'item-1',
          'item_type': 'activity',
          'title': 'Visit Senso-ji',
          'start_time': '2026-06-01T09:00:00.000Z',
          'end_time': null,
          'location': null,
          'latitude': null,
          'longitude': null,
        },
      ],
      'segments': [
        {
          'id': 'seg-1',
          'itinerary_id': 'it-1',
          'order_index': 0,
          'transport_mode': 'flight',
          'origin_name': 'Munich',
          'origin_lat': 48.1351,
          'origin_lng': 11.5820,
          'destination_name': 'Bangkok',
          'destination_lat': 13.7563,
          'destination_lng': 100.5018,
        },
      ],
    },
  };

  group('ItineraryPostModel.fromJson', () {
    test('parses top-level fields', () {
      final post = ItineraryPostModel.fromJson(fullJson);

      expect(post.id, 'post-1');
      expect(post.sourceItineraryId, 'it-1');
      expect(post.authorId, 'user-1');
      expect(post.authorName, 'Alice');
      expect(post.authorAvatarUrl, 'https://example.com/a.png');
      expect(post.forkedFromPostId, 'post-0');
      expect(post.title, 'Tokyo Summer 2026');
      expect(post.description, 'A week in Tokyo');
      expect(post.themeKey, 'sakura');
      expect(post.currencyCode, 'JPY');
      expect(post.likeCount, 4);
    });

    test('parses nested snapshot items and segments', () {
      final post = ItineraryPostModel.fromJson(fullJson);

      expect(post.items, hasLength(1));
      expect(post.items.single.title, 'Visit Senso-ji');
      expect(post.segments, hasLength(1));
      expect(post.segments.single.origin.name, 'Munich');
      expect(post.segments.single.destination.name, 'Bangkok');
    });

    test('defaults likedByMe to false unless passed', () {
      final post = ItineraryPostModel.fromJson(fullJson);
      expect(post.likedByMe, isFalse);
    });

    test('honors the likedByMe parameter', () {
      final post = ItineraryPostModel.fromJson(fullJson, likedByMe: true);
      expect(post.likedByMe, isTrue);
    });

    test('defaults forkedFromPostId/authorAvatarUrl to null when absent', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..remove('forked_from_post_id')
        ..remove('author_avatar_url');
      final post = ItineraryPostModel.fromJson(json);

      expect(post.forkedFromPostId, isNull);
      expect(post.authorAvatarUrl, isNull);
    });

    test('handles an empty snapshot (no items/segments)', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['snapshot'] = <String, dynamic>{};
      final post = ItineraryPostModel.fromJson(json);

      expect(post.items, isEmpty);
      expect(post.segments, isEmpty);
    });
  });

  group('ItineraryPostModel.buildInsertJson', () {
    final tItinerary = TravelItinerary(
      id: 'it-1',
      title: 'Tokyo Summer 2026',
      description: 'A week in Tokyo',
      ownerId: 'user-1',
      startDate: DateTime.utc(2026, 6),
      endDate: DateTime.utc(2026, 6, 7),
      totalBudget: 2000,
      currencyCode: 'JPY',
      members: const [],
      items: [tItem],
      expenseSummary: const ExpenseSummary(
        totalSpent: 0,
        spentByCategory: {},
        memberBalances: {},
      ),
      createdAt: DateTime.utc(2026, 5),
      updatedAt: DateTime.utc(2026, 5),
      themeKey: 'sakura',
    );

    test('carries author + itinerary fields, with no forked_from_post_id '
        'when originPostId is unset', () {
      final json = ItineraryPostModel.buildInsertJson(
        itinerary: tItinerary,
        segments: const [tSegment],
        authorId: 'user-1',
        authorName: 'Alice',
      );

      expect(json['source_itinerary_id'], 'it-1');
      expect(json['author_id'], 'user-1');
      expect(json['author_name'], 'Alice');
      expect(json['title'], 'Tokyo Summer 2026');
      expect(json['theme_key'], 'sakura');
      expect(json['currency_code'], 'JPY');
      expect(json.containsKey('forked_from_post_id'), isFalse);
    });

    test(
      'sets forked_from_post_id from itinerary.originPostId when present',
      () {
        final forkedItinerary = tItinerary.copyWith(originPostId: 'post-0');

        final json = ItineraryPostModel.buildInsertJson(
          itinerary: forkedItinerary,
          segments: const [tSegment],
          authorId: 'user-1',
          authorName: 'Alice',
        );

        expect(json['forked_from_post_id'], 'post-0');
      },
    );

    test('embeds items and segments in the snapshot', () {
      final json = ItineraryPostModel.buildInsertJson(
        itinerary: tItinerary,
        segments: const [tSegment],
        authorId: 'user-1',
        authorName: 'Alice',
      );

      final snapshot = json['snapshot'] as Map<String, dynamic>;
      final items = snapshot['items'] as List<dynamic>;
      final segments = snapshot['segments'] as List<dynamic>;

      expect(items, hasLength(1));
      expect((items.single as Map<String, dynamic>)['title'], 'Visit Senso-ji');
      expect(segments, hasLength(1));
      expect(
        (segments.single as Map<String, dynamic>)['origin_name'],
        'Munich',
      );
    });

    test('omits author_avatar_url when not provided', () {
      final json = ItineraryPostModel.buildInsertJson(
        itinerary: tItinerary,
        segments: const [tSegment],
        authorId: 'user-1',
        authorName: 'Alice',
      );

      expect(json.containsKey('author_avatar_url'), isFalse);
    });
  });
}
