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

  /// [row] comes from the `fetch_org_pending_approvals` RPC (stage32) — a
  /// flat `trip_title` column, not a nested `itineraries` embed. That RPC
  /// does its own authorization + join server-side specifically so the
  /// client never needs (and the DB never grants) direct SELECT access to
  /// `itineraries` for this purpose — see stage32's migration comment for
  /// why a raw PostgREST embed was a data-exposure vulnerability here.
  factory PendingExpenseApprovalModel.fromJson(Map<String, dynamic> row) =>
      PendingExpenseApprovalModel(
        expenseId: row['id'] as String,
        itineraryId: row['itinerary_id'] as String,
        tripTitle: row['trip_title'] as String,
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
