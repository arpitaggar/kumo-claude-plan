import 'dart:async';

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
          .transform(
            // `Stream.handleError`'s callback return value is silently
            // discarded — it only suppresses the error, it can't inject a
            // replacement event. A `StreamTransformer` sink is the only way to
            // turn an upstream stream error into a `Left(...)` value.
            StreamTransformer.fromHandlers(
              handleData: (data, sink) => sink.add(Right(data)),
              handleError: (error, stackTrace, sink) => sink.add(
                Left(
                  error is ServerException
                      ? ServerFailure(error.message)
                      : UnexpectedFailure(error.toString()),
                ),
              ),
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
        splitMode: expense.splitMode,
        exchangeRateToBase: expense.exchangeRateToBase,
        isSettlement: expense.isSettlement,
        notes: expense.notes,
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

  @override
  Future<Either<Failure, void>> submitForApproval(
    List<String> expenseIds,
  ) async {
    try {
      await dataSource.submitForApproval(expenseIds);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
