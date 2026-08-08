import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class AddExpenseUseCase {
  const AddExpenseUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<Either<Failure, Expense>> call({
    required String itineraryId,
    required String title,
    required double amount,
    required String currencyCode,
    required ExpenseCategory category,
    required String payerId,
    required String payerName,
    required List<ExpenseSplit> splits,
    SplitMode splitMode = SplitMode.equal,
    double exchangeRateToBase = 1.0,
    bool isSettlement = false,
    String? notes,
  }) {
    final expense = Expense(
      id: const Uuid().v4(),
      itineraryId: itineraryId,
      title: title.trim(),
      amount: amount,
      currencyCode: currencyCode,
      category: category,
      payerId: payerId,
      payerName: payerName,
      splits: splits,
      createdAt: DateTime.now().toUtc(),
      splitMode: splitMode,
      exchangeRateToBase: exchangeRateToBase,
      isSettlement: isSettlement,
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
    );
    return _repository.addExpense(expense);
  }
}
