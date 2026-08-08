import '../../domain/entities/pending_expense_approval.dart';

class PendingExpenseApprovalModel extends PendingExpenseApproval {
  const PendingExpenseApprovalModel({
    required super.expenseId,
    required super.itineraryId,
    required super.tripTitle,
    required super.payerId,
    required super.payerName,
    required super.title,
    required super.amount,
    required super.currencyCode,
    required super.category,
    required super.submittedAt,
    super.notes,
    super.costCenterCode,
  });

  /// [row] is an `expenses` row with an embedded `itineraries(title)` —
  /// see `OrganizationRemoteDataSourceImpl.fetchPendingApprovals`'s
  /// `itineraries!inner(title)` select.
  factory PendingExpenseApprovalModel.fromJson(Map<String, dynamic> row) =>
      PendingExpenseApprovalModel(
        expenseId: row['id'] as String,
        itineraryId: row['itinerary_id'] as String,
        tripTitle: (row['itineraries'] as Map<String, dynamic>)['title'] as String,
        payerId: row['payer_id'] as String,
        payerName: row['payer_name'] as String,
        title: row['title'] as String,
        amount: (row['amount'] as num).toDouble(),
        currencyCode: row['currency_code'] as String,
        category: row['category'] as String,
        submittedAt: DateTime.parse(row['submitted_at'] as String).toUtc(),
        notes: row['notes'] as String?,
        costCenterCode: row['cost_center_code'] as String?,
      );
}
