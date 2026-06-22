import 'package:equatable/equatable.dart';

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
  });

  final String id;
  final String itineraryId;
  final String title;
  final double amount;
  final String currencyCode;
  final ExpenseCategory category;
  final String payerId;
  final String payerName;

  /// Shares owed by non-payer members to the payer.
  final List<ExpenseSplit> splits;

  final DateTime createdAt;

  @override
  List<Object> get props => [
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
      ];
}

class ExpenseSplit extends Equatable {
  const ExpenseSplit({
    required this.userId,
    required this.userName,
    required this.shareAmount,
  });

  final String userId;
  final String userName;

  /// Amount this person owes the payer.
  final double shareAmount;

  @override
  List<Object> get props => [userId, userName, shareAmount];
}

/// A suggested payment to settle debts — computed client-side.
class Settlement extends Equatable {
  const Settlement({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
  });

  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;

  @override
  List<Object> get props =>
      [fromUserId, fromUserName, toUserId, toUserName, amount];
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
