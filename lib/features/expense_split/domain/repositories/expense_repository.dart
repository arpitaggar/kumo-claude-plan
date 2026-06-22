import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/expense.dart';

abstract class ExpenseRepository {
  Stream<Either<Failure, List<Expense>>> watchExpenses(String itineraryId);

  Future<Either<Failure, Expense>> addExpense(Expense expense);

  Future<Either<Failure, void>> deleteExpense(String expenseId);
}
