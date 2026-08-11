import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/packing/data/models/packing_item_model.dart';

void main() {
  group('PackingItemModel.fromJson', () {
    test('parses every field', () {
      final model = PackingItemModel.fromJson({
        'id': 'item-1',
        'itinerary_id': 'trip-1',
        'title': 'Passport',
        'is_checked': true,
        'added_by_id': 'user-1',
        'added_by_name': 'Alice',
        'created_at': '2026-01-01T00:00:00.000Z',
        'category': 'documents',
      });

      expect(model.id, 'item-1');
      expect(model.itineraryId, 'trip-1');
      expect(model.title, 'Passport');
      expect(model.isChecked, isTrue);
      expect(model.addedById, 'user-1');
      expect(model.addedByName, 'Alice');
      expect(model.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(model.category, 'documents');
    });

    test('defaults isChecked to false and category to null when absent', () {
      final model = PackingItemModel.fromJson({
        'id': 'item-1',
        'itinerary_id': 'trip-1',
        'title': 'Passport',
        'added_by_id': 'user-1',
        'added_by_name': 'Alice',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.isChecked, isFalse);
      expect(model.category, isNull);
    });
  });

  group('PackingItemModel.toJson', () {
    test('round-trips through fromJson', () {
      final original = PackingItemModel.fromJson({
        'id': 'item-1',
        'itinerary_id': 'trip-1',
        'title': 'Passport',
        'is_checked': true,
        'added_by_id': 'user-1',
        'added_by_name': 'Alice',
        'created_at': '2026-01-01T00:00:00.000Z',
        'category': 'documents',
      });

      final roundTripped = PackingItemModel.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.itineraryId, original.itineraryId);
      expect(roundTripped.title, original.title);
      expect(roundTripped.isChecked, original.isChecked);
      expect(roundTripped.addedById, original.addedById);
      expect(roundTripped.addedByName, original.addedByName);
      expect(roundTripped.createdAt, original.createdAt);
      expect(roundTripped.category, original.category);
    });

    test('omits category from the JSON map when null', () {
      final model = PackingItemModel.fromJson({
        'id': 'item-1',
        'itinerary_id': 'trip-1',
        'title': 'Passport',
        'added_by_id': 'user-1',
        'added_by_name': 'Alice',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.toJson().containsKey('category'), isFalse);
    });
  });
}
