import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/expense_repository.dart';

class DeleteExpenseUseCase {
  const DeleteExpenseUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<Either<Failure, void>> call(String expenseId) =>
      _repository.deleteExpense(expenseId);
}
