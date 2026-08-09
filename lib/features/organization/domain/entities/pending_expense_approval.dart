import 'package:equatable/equatable.dart';

/// A submitted-for-approval expense as seen by an org admin reviewing it —
/// a deliberately separate, narrower shape from `expense_split`'s `Expense`
/// entity (this feature only ever needs to display and approve/reject a
/// submission, never the full per-trip split/settlement machinery), which
/// also avoids a domain-to-domain dependency between the `organization` and
/// `expense_split` features. See stage29's migration for the RLS that makes
/// this query return only expenses a traveler actually chose to submit.
class PendingExpenseApproval extends Equatable {
  const PendingExpenseApproval({
    required this.expenseId,
    required this.itineraryId,
    required this.tripTitle,
    required this.payerId,
    required this.payerName,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.submittedAt,
    this.notes,
    this.costCenterCode,
  });

  final String expenseId;
  final String itineraryId;
  final String tripTitle;
  final String payerId;
  final String payerName;
  final String title;
  final double amount;
  final String currencyCode;
  final String category;
  final DateTime submittedAt;
  final String? notes;

  /// Snapshotted cost-center code, if the org has one configured and the
  /// trip's fields were fully assigned at submit time — see stage30.
  final String? costCenterCode;

  @override
  List<Object?> get props => [
    expenseId,
    itineraryId,
    tripTitle,
    payerId,
    payerName,
    title,
    amount,
    currencyCode,
    category,
    submittedAt,
    notes,
    costCenterCode,
  ];
}
