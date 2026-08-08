import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/expense_repository.dart';

/// Flags one or more expenses official and moves them into review — covers
/// both "submit a single expense" and "select several, submit at once",
/// and "resubmit after a rejection" (same call, see the repository doc).
class SubmitExpensesForApprovalUseCase {
  const SubmitExpensesForApprovalUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<Either<Failure, void>> call(List<String> expenseIds) =>
      _repository.submitForApproval(expenseIds);
}
