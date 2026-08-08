import 'package:equatable/equatable.dart';

enum SplitMode { equal, percentage, ratio }

class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.itineraryId,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.payerId,
    required this.payerName,
    required this.splits,
    required this.createdAt,
    this.splitMode = SplitMode.equal,
    this.exchangeRateToBase = 1.0,
    this.isSettlement = false,
    this.isOfficial = false,
    this.approvalStatus = ExpenseApprovalStatus.notSubmitted,
    this.notes,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.costCenterCode,
  });

  final String id;
  final String itineraryId;
  final String title;
  final double amount;
  final String currencyCode;
  final ExpenseCategory category;
  final String payerId;
  final String payerName;

  /// Shares owed by non-payer members to the payer, in [currencyCode].
  final List<ExpenseSplit> splits;

  final DateTime createdAt;

  /// How splits were calculated.
  final SplitMode splitMode;

  /// 1 unit of [currencyCode] = [exchangeRateToBase] units of the trip base currency.
  /// Used by the settlement calculator to normalise cross-currency debts.
  final double exchangeRateToBase;

  /// True for cash settle-up payments. Excluded from budget totals; included
  /// in the settlement calculator so debts cancel out correctly.
  final bool isSettlement;

  /// Whether this is work/official spending, submitted (or submittable) for
  /// an org admin to approve — see stage29's migration. Meaningless on a
  /// trip with no `orgId`.
  final bool isOfficial;

  final ExpenseApprovalStatus approvalStatus;

  /// Free-text context for the approver — doesn't exist for personal
  /// expenses, but available on any expense (not gated on [isOfficial]).
  final String? notes;

  /// Set by the approver on rejection; cleared on resubmit.
  final String? rejectionReason;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// UUID of the org admin/owner who approved/rejected this, if reviewed.
  final String? reviewedBy;

  /// Snapshotted from the trip's org cost-tracking fields at submit/resubmit
  /// time (see stage30's migration) — never live-derived, so correcting the
  /// trip's assignment later doesn't retroactively change an already-
  /// submitted/approved expense's account. Null on a personal trip, an org
  /// with no generated field configured, or an incomplete assignment.
  final String? costCenterCode;

  @override
  List<Object?> get props => [
        id,
        itineraryId,
        title,
        amount,
        currencyCode,
        category,
        payerId,
        payerName,
        splits,
        createdAt,
        splitMode,
        exchangeRateToBase,
        isSettlement,
        isOfficial,
        approvalStatus,
        notes,
        rejectionReason,
        submittedAt,
        reviewedAt,
        reviewedBy,
        costCenterCode,
      ];
}

enum ExpenseApprovalStatus { notSubmitted, pending, approved, rejected }

class ExpenseSplit extends Equatable {
  const ExpenseSplit({
    required this.userId,
    required this.userName,
    required this.shareAmount,
    this.rawValue,
  });

  final String userId;
  final String userName;

  /// Amount this person owes the payer, in the expense currency.
  final double shareAmount;

  /// The raw percentage (0–100) or ratio value entered by the user.
  /// Null for equal splits. Stored for display purposes only.
  final double? rawValue;

  @override
  List<Object?> get props => [userId, userName, shareAmount, rawValue];
}

/// A suggested payment to settle debts — computed client-side in base currency.
class Settlement extends Equatable {
  const Settlement({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
    required this.currencyCode,
  });

  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;

  /// Amount in the trip's base currency.
  final double amount;

  /// Always the trip's base currency code.
  final String currencyCode;

  @override
  List<Object> get props =>
      [fromUserId, fromUserName, toUserId, toUserName, amount, currencyCode];
}

enum ExpenseCategory {
  food('Food & Drink', 0xFF2E7D52),
  transport('Transport', 0xFF1565C0),
  accommodation('Accommodation', 0xFF6A1B9A),
  activities('Activities', 0xFFE65100),
  shopping('Shopping', 0xFFC62828),
  other('Other', 0xFF546E7A);

  const ExpenseCategory(this.label, this.colorValue);
  final String label;
  final int colorValue;
}
