import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/ratings/data/models/rating_model.dart';

void main() {
  final fullJson = <String, dynamic>{
    'id': 'rating-1',
    'itinerary_id': 'itinerary-1',
    'item_id': 'item-1',
    'target_name': 'Senso-ji Temple',
    'stars': 5,
    'comment': 'Absolutely stunning!',
    'user_id': 'alice',
    'user_name': 'Alice',
    'created_at': '2026-06-15T09:00:00.000Z',
  };

  group('RatingModel.fromJson', () {
    test('parses all fields correctly', () {
      final model = RatingModel.fromJson(fullJson);

      expect(model.id, 'rating-1');
      expect(model.itineraryId, 'itinerary-1');
      expect(model.itemId, 'item-1');
      expect(model.targetName, 'Senso-ji Temple');
      expect(model.stars, 5);
      expect(model.comment, 'Absolutely stunning!');
      expect(model.userId, 'alice');
      expect(model.userName, 'Alice');
      expect(model.createdAt, DateTime.utc(2026, 6, 15, 9));
    });

    test('parses null itemId correctly', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['item_id'] = null;
      final model = RatingModel.fromJson(json);
      expect(model.itemId, isNull);
    });

    test('parses missing itemId as null', () {
      final json = Map<String, dynamic>.from(fullJson)..remove('item_id');
      final model = RatingModel.fromJson(json);
      expect(model.itemId, isNull);
    });

    test('parses null comment correctly', () {
      final json = Map<String, dynamic>.from(fullJson)..['comment'] = null;
      final model = RatingModel.fromJson(json);
      expect(model.comment, isNull);
    });

    test('parses stars as int', () {
      final model = RatingModel.fromJson(fullJson);
      expect(model.stars, isA<int>());
      expect(model.stars, inInclusiveRange(1, 5));
    });

    test('createdAt is parsed as UTC', () {
      final model = RatingModel.fromJson(fullJson);
      expect(model.createdAt.isUtc, isTrue);
    });
  });

  group('RatingModel.toJson', () {
    late RatingModel model;

    setUp(() {
      model = RatingModel.fromJson(fullJson);
    });

    test('serialises id correctly', () {
      expect(model.toJson()['id'], 'rating-1');
    });

    test('serialises target_name correctly', () {
      expect(model.toJson()['target_name'], 'Senso-ji Temple');
    });

    test('includes item_id when present', () {
      expect(model.toJson().containsKey('item_id'), isTrue);
      expect(model.toJson()['item_id'], 'item-1');
    });

    test('omits item_id when null', () {
      final modelWithoutItem = RatingModel(
        id: 'rating-2',
        itineraryId: 'itinerary-1',
        targetName: 'Ramen Shop',
        stars: 4,
        userId: 'bob',
        userName: 'Bob',
        createdAt: DateTime.utc(2026, 6, 15),
      );
      expect(modelWithoutItem.toJson().containsKey('item_id'), isFalse);
    });

    test('omits comment when null', () {
      final modelWithoutComment = RatingModel(
        id: 'rating-3',
        itineraryId: 'itinerary-1',
        targetName: 'Park',
        stars: 3,
        userId: 'carol',
        userName: 'Carol',
        createdAt: DateTime.utc(2026, 6, 15),
      );
      expect(modelWithoutComment.toJson().containsKey('comment'), isFalse);
    });

    test('round-trip preserves all fields', () {
      final json = model.toJson();
      final model2 = RatingModel.fromJson(json);

      expect(model2.id, model.id);
      expect(model2.itineraryId, model.itineraryId);
      expect(model2.itemId, model.itemId);
      expect(model2.targetName, model.targetName);
      expect(model2.stars, model.stars);
      expect(model2.comment, model.comment);
      expect(model2.userId, model.userId);
      expect(model2.userName, model.userName);
    });
  });
}
