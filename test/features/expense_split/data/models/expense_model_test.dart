import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/expense_split/data/models/expense_model.dart';
import 'package:kumo_claude/features/expense_split/domain/entities/expense.dart';

void main() {
  final createdAt = DateTime.utc(2026, 6, 1, 12);

  final fullJson = <String, dynamic>{
    'id': 'expense-1',
    'itinerary_id': 'itinerary-1',
    'title': 'Dinner',
    'amount': 90.00,
    'currency_code': 'USD',
    'category': 'food',
    'payer_id': 'alice',
    'payer_name': 'Alice',
    'splits': [
      {'userId': 'bob', 'userName': 'Bob', 'shareAmount': 30.0},
      {'userId': 'carol', 'userName': 'Carol', 'shareAmount': 30.0},
    ],
    'created_at': '2026-06-01T12:00:00.000Z',
  };

  group('ExpenseModel.fromJson', () {
    test('parses all fields correctly', () {
      final model = ExpenseModel.fromJson(fullJson);

      expect(model.id, 'expense-1');
      expect(model.itineraryId, 'itinerary-1');
      expect(model.title, 'Dinner');
      expect(model.amount, 90.0);
      expect(model.currencyCode, 'USD');
      expect(model.category, ExpenseCategory.food);
      expect(model.payerId, 'alice');
      expect(model.payerName, 'Alice');
      expect(model.createdAt, createdAt);
    });

    test('parses splits correctly', () {
      final model = ExpenseModel.fromJson(fullJson);

      expect(model.splits, hasLength(2));
      expect(model.splits[0].userId, 'bob');
      expect(model.splits[0].userName, 'Bob');
      expect(model.splits[0].shareAmount, 30.0);
      expect(model.splits[1].userId, 'carol');
      expect(model.splits[1].shareAmount, 30.0);
    });

    test('uses empty splits when splits key missing', () {
      final json = Map<String, dynamic>.from(fullJson)..remove('splits');
      final model = ExpenseModel.fromJson(json);
      expect(model.splits, isEmpty);
    });

    test('falls back to USD when currency_code missing', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..remove('currency_code');
      final model = ExpenseModel.fromJson(json);
      expect(model.currencyCode, 'USD');
    });

    test('defaults to ExpenseCategory.other for unknown category', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['category'] = 'unicorn';
      final model = ExpenseModel.fromJson(json);
      expect(model.category, ExpenseCategory.other);
    });

    test('parses integer amount as double', () {
      final json = Map<String, dynamic>.from(fullJson)..['amount'] = 90;
      final model = ExpenseModel.fromJson(json);
      expect(model.amount, 90.0);
      expect(model.amount, isA<double>());
    });
  });

  group('ExpenseModel.toJson', () {
    late ExpenseModel model;

    setUp(() {
      model = ExpenseModel.fromJson(fullJson);
    });

    test('serialises id correctly', () {
      expect(model.toJson()['id'], 'expense-1');
    });

    test('serialises category as name string', () {
      expect(model.toJson()['category'], 'food');
    });

    test('serialises splits as list of maps', () {
      final splits = model.toJson()['splits'] as List;
      expect(splits, hasLength(2));
      expect(splits[0]['userId'], 'bob');
      expect(splits[0]['shareAmount'], 30.0);
    });

    test('round-trip: fromJson → toJson → fromJson preserves data', () {
      final json1 = model.toJson();
      final model2 = ExpenseModel.fromJson(json1);

      expect(model2.id, model.id);
      expect(model2.title, model.title);
      expect(model2.category, model.category);
      expect(model2.splits.length, model.splits.length);
    });
  });
}
