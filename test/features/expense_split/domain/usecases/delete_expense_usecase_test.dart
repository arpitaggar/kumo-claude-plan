import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/expense_split/domain/repositories/expense_repository.dart';
import 'package:kumo_claude/features/expense_split/domain/usecases/delete_expense_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

void main() {
  late MockExpenseRepository mockRepo;
  late DeleteExpenseUseCase useCase;

  setUp(() {
    mockRepo = MockExpenseRepository();
    useCase = DeleteExpenseUseCase(mockRepo);
  });

  test('delegates to repository with the given id', () async {
    when(
      () => mockRepo.deleteExpense('expense-1'),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase('expense-1');

    verify(() => mockRepo.deleteExpense('expense-1')).called(1);
    expect(result, const Right<Failure, void>(null));
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.deleteExpense(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('expense-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
