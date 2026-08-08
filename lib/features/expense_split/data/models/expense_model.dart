import '../../domain/entities/expense.dart';

class ExpenseModel extends Expense {
  const ExpenseModel({
    required super.id,
    required super.itineraryId,
    required super.title,
    required super.amount,
    required super.currencyCode,
    required super.category,
    required super.payerId,
    required super.payerName,
    required super.splits,
    required super.createdAt,
    super.splitMode,
    super.exchangeRateToBase,
    super.isSettlement,
    super.isOfficial,
    super.approvalStatus,
    super.notes,
    super.rejectionReason,
    super.submittedAt,
    super.reviewedAt,
    super.reviewedBy,
    super.costCenterCode,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category'] as String? ?? 'other';
    final category = ExpenseCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => ExpenseCategory.other,
    );

    final splitModeStr = json['split_mode'] as String? ?? 'equal';
    final splitMode = SplitMode.values.firstWhere(
      (m) => m.name == splitModeStr,
      orElse: () => SplitMode.equal,
    );

    final approvalStatus = _approvalStatusFromJson(
      json['approval_status'] as String?,
    );

    final rawSplits = json['splits'] as List<dynamic>? ?? [];
    final splits = rawSplits
        .map((s) => ExpenseSplit(
              userId: s['userId'] as String,
              userName: s['userName'] as String,
              shareAmount: (s['shareAmount'] as num).toDouble(),
              rawValue: s['rawValue'] != null
                  ? (s['rawValue'] as num).toDouble()
                  : null,
            ))
        .toList();

    return ExpenseModel(
      id: json['id'] as String,
      itineraryId: json['itinerary_id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currency_code'] as String? ?? 'USD',
      category: category,
      payerId: json['payer_id'] as String,
      payerName: json['payer_name'] as String,
      splits: splits,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      splitMode: splitMode,
      exchangeRateToBase:
          (json['exchange_rate_to_base'] as num?)?.toDouble() ?? 1.0,
      isSettlement: json['is_settlement'] as bool? ?? false,
      isOfficial: json['is_official'] as bool? ?? false,
      approvalStatus: approvalStatus,
      notes: json['notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String).toUtc()
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String).toUtc()
          : null,
      reviewedBy: json['reviewed_by'] as String?,
      costCenterCode: json['cost_center_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'itinerary_id': itineraryId,
        'title': title,
        'amount': amount,
        'currency_code': currencyCode,
        'category': category.name,
        'payer_id': payerId,
        'payer_name': payerName,
        'splits': splits
            .map((s) => {
                  'userId': s.userId,
                  'userName': s.userName,
                  'shareAmount': s.shareAmount,
                  if (s.rawValue != null) 'rawValue': s.rawValue,
                })
            .toList(),
        'created_at': createdAt.toIso8601String(),
        'split_mode': splitMode.name,
        'exchange_rate_to_base': exchangeRateToBase,
        'is_settlement': isSettlement,
        'is_official': isOfficial,
        'approval_status': _approvalStatusToJson(approvalStatus),
        if (notes != null) 'notes': notes,
      };
}

/// `ExpenseApprovalStatus.notSubmitted` <-> `'not_submitted'` — every other
/// value's Dart name already matches its DB value verbatim.
ExpenseApprovalStatus _approvalStatusFromJson(String? raw) => switch (raw) {
      'pending' => ExpenseApprovalStatus.pending,
      'approved' => ExpenseApprovalStatus.approved,
      'rejected' => ExpenseApprovalStatus.rejected,
      _ => ExpenseApprovalStatus.notSubmitted,
    };

String _approvalStatusToJson(ExpenseApprovalStatus status) =>
    switch (status) {
      ExpenseApprovalStatus.notSubmitted => 'not_submitted',
      ExpenseApprovalStatus.pending => 'pending',
      ExpenseApprovalStatus.approved => 'approved',
      ExpenseApprovalStatus.rejected => 'rejected',
    };
