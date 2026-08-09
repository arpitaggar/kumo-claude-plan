import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/data/models/pending_expense_approval_model.dart';

void main() {
  final fullRow = <String, dynamic>{
    'id': 'exp-1',
    'itinerary_id': 'it-1',
    'trip_title': 'Berlin Offsite',
    'payer_id': 'user-1',
    'payer_name': 'Bob',
    'title': 'Client dinner',
    'amount': 90.0,
    'currency_code': 'EUR',
    'category': 'food',
    'submitted_at': '2026-06-02T09:00:00.000Z',
  };

  test(
    'parses the trip title from the fetch_org_pending_approvals RPC row',
    () {
      final model = PendingExpenseApprovalModel.fromJson(fullRow);
      expect(model.tripTitle, 'Berlin Offsite');
    },
  );

  test('defaults costCenterCode to null when absent', () {
    final model = PendingExpenseApprovalModel.fromJson(fullRow);
    expect(model.costCenterCode, isNull);
  });

  test('parses a snapshotted cost_center_code', () {
    final row = Map<String, dynamic>.from(fullRow)
      ..['cost_center_code'] = 'SAL-FAL';
    final model = PendingExpenseApprovalModel.fromJson(row);
    expect(model.costCenterCode, 'SAL-FAL');
  });

  test('defaults notes to null when absent', () {
    final model = PendingExpenseApprovalModel.fromJson(fullRow);
    expect(model.notes, isNull);
  });
}
