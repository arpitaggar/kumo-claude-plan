import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/expense_split/domain/repositories/expense_repository.dart';
import 'package:kumo_claude/features/expense_split/domain/usecases/submit_expenses_for_approval_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

void main() {
  late MockExpenseRepository mockRepo;
  late SubmitExpensesForApprovalUseCase useCase;

  setUp(() {
    mockRepo = MockExpenseRepository();
    useCase = SubmitExpensesForApprovalUseCase(mockRepo);
  });

  test('delegates to repository with the provided ids', () async {
    when(() => mockRepo.submitForApproval(['e-1', 'e-2']))
        .thenAnswer((_) async => const Right(null));

    await useCase(['e-1', 'e-2']);

    verify(() => mockRepo.submitForApproval(['e-1', 'e-2'])).called(1);
  });

  test('works for a single expense id', () async {
    when(() => mockRepo.submitForApproval(['e-1']))
        .thenAnswer((_) async => const Right(null));

    final result = await useCase(['e-1']);

    expect(result.isRight(), isTrue);
  });

  test('propagates ServerFailure from repository', () async {
    when(() => mockRepo.submitForApproval(any()))
        .thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(['e-1']);

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
