import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/expense_remote_datasource.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/usecases/add_expense_usecase.dart';
import '../../domain/usecases/calculate_settlements_usecase.dart';
import '../../domain/usecases/delete_expense_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

final expenseDataSourceProvider = Provider<ExpenseRemoteDataSource>(
  (_) => const ExpenseRemoteDataSourceImpl(),
);

final expenseRepositoryProvider = Provider<ExpenseRepositoryImpl>(
  (ref) => ExpenseRepositoryImpl(
    dataSource: ref.watch(expenseDataSourceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final addExpenseUseCaseProvider = Provider<AddExpenseUseCase>(
  (ref) => AddExpenseUseCase(ref.watch(expenseRepositoryProvider)),
);

final deleteExpenseUseCaseProvider = Provider<DeleteExpenseUseCase>(
  (ref) => DeleteExpenseUseCase(ref.watch(expenseRepositoryProvider)),
);

final calculateSettlementsUseCaseProvider =
    Provider<CalculateSettlementsUseCase>(
  (_) => const CalculateSettlementsUseCase(),
);

// ---------------------------------------------------------------------------
// Stream provider — live expense list per itinerary
// ---------------------------------------------------------------------------

final expenseStreamProvider =
    StreamProvider.family<List<Expense>, String>((ref, itineraryId) => ref
        .watch(expenseRepositoryProvider)
        .watchExpenses(itineraryId)
        .map((either) => either.fold(
              (f) => throw Exception(f.message),
              (list) => list,
            )));

// ---------------------------------------------------------------------------
// Derived: settlements computed from live expenses
// ---------------------------------------------------------------------------

final settlementsProvider =
    Provider.family<List<Settlement>, String>((ref, itineraryId) {
  final expenses =
      ref.watch(expenseStreamProvider(itineraryId)).value ?? [];
  return ref.watch(calculateSettlementsUseCaseProvider)(expenses);
});
