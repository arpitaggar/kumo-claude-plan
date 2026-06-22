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
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category'] as String? ?? 'other';
    final category = ExpenseCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => ExpenseCategory.other,
    );

    final rawSplits = json['splits'] as List<dynamic>? ?? [];
    final splits = rawSplits
        .map((s) => ExpenseSplit(
              userId: s['userId'] as String,
              userName: s['userName'] as String,
              shareAmount: (s['shareAmount'] as num).toDouble(),
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
                })
            .toList(),
        'created_at': createdAt.toIso8601String(),
      };
}
