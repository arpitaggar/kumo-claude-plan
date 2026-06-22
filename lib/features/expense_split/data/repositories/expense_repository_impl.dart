import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expense_remote_datasource.dart';
import '../models/expense_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  const ExpenseRepositoryImpl({required this.dataSource});

  final ExpenseRemoteDataSource dataSource;

  @override
  Stream<Either<Failure, List<Expense>>> watchExpenses(String itineraryId) =>
      dataSource
          .watchExpenses(itineraryId)
          .map<Either<Failure, List<Expense>>>(Right.new)
          .handleError(
            (Object e) => Left(
              e is ServerException
                  ? ServerFailure(e.message)
                  : UnexpectedFailure(e.toString()),
            ),
          );

  @override
  Future<Either<Failure, Expense>> addExpense(Expense expense) async {
    try {
      final model = ExpenseModel(
        id: expense.id,
        itineraryId: expense.itineraryId,
        title: expense.title,
        amount: expense.amount,
        currencyCode: expense.currencyCode,
        category: expense.category,
        payerId: expense.payerId,
        payerName: expense.payerName,
        splits: expense.splits,
        createdAt: expense.createdAt,
      );
      final saved = await dataSource.addExpense(model);
      return Right(saved);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExpense(String expenseId) async {
    try {
      await dataSource.deleteExpense(expenseId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
