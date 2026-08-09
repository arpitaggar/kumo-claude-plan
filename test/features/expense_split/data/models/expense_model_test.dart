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
      final json = Map<String, dynamic>.from(fullJson)..remove('currency_code');
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

    test('defaults isOfficial/approvalStatus/notes when absent (old rows)', () {
      final model = ExpenseModel.fromJson(fullJson);
      expect(model.isOfficial, isFalse);
      expect(model.approvalStatus, ExpenseApprovalStatus.notSubmitted);
      expect(model.notes, isNull);
      expect(model.rejectionReason, isNull);
      expect(model.submittedAt, isNull);
      expect(model.reviewedAt, isNull);
      expect(model.reviewedBy, isNull);
    });

    test('parses a pending, official, submitted expense', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['is_official'] = true
        ..['approval_status'] = 'pending'
        ..['notes'] = 'Client dinner'
        ..['submitted_at'] = '2026-06-02T09:00:00.000Z';
      final model = ExpenseModel.fromJson(json);

      expect(model.isOfficial, isTrue);
      expect(model.approvalStatus, ExpenseApprovalStatus.pending);
      expect(model.notes, 'Client dinner');
      expect(model.submittedAt, DateTime.utc(2026, 6, 2, 9));
    });

    test('parses a rejected expense with a reviewer and reason', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['is_official'] = true
        ..['approval_status'] = 'rejected'
        ..['rejection_reason'] = 'Missing receipt'
        ..['reviewed_by'] = 'admin-1'
        ..['reviewed_at'] = '2026-06-03T09:00:00.000Z';
      final model = ExpenseModel.fromJson(json);

      expect(model.approvalStatus, ExpenseApprovalStatus.rejected);
      expect(model.rejectionReason, 'Missing receipt');
      expect(model.reviewedBy, 'admin-1');
      expect(model.reviewedAt, DateTime.utc(2026, 6, 3, 9));
    });

    test('defaults costCenterCode to null when absent', () {
      final model = ExpenseModel.fromJson(fullJson);
      expect(model.costCenterCode, isNull);
    });

    test('parses a snapshotted cost_center_code', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['cost_center_code'] = 'SAL-FAL';
      final model = ExpenseModel.fromJson(json);
      expect(model.costCenterCode, 'SAL-FAL');
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

    test('always includes is_official and approval_status', () {
      final json = model.toJson();
      expect(json['is_official'], isFalse);
      expect(json['approval_status'], 'not_submitted');
    });

    test('omits notes when null', () {
      expect(model.toJson().containsKey('notes'), isFalse);
    });

    test('round-trip preserves isOfficial/approvalStatus/notes', () {
      final official = ExpenseModel.fromJson(
        Map<String, dynamic>.from(fullJson)
          ..['is_official'] = true
          ..['approval_status'] = 'approved'
          ..['notes'] = 'Conference ticket',
      );

      final roundTripped = ExpenseModel.fromJson(official.toJson());

      expect(roundTripped.isOfficial, isTrue);
      expect(roundTripped.approvalStatus, ExpenseApprovalStatus.approved);
      expect(roundTripped.notes, 'Conference ticket');
    });
  });
}
