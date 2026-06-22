import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/expense_split/domain/entities/expense.dart';
import 'package:kumo_claude/features/expense_split/domain/repositories/expense_repository.dart';
import 'package:kumo_claude/features/expense_split/domain/usecases/add_expense_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

class FakeExpense extends Fake implements Expense {}

void main() {
  late MockExpenseRepository mockRepo;
  late AddExpenseUseCase useCase;

  final tSplits = [
    const ExpenseSplit(userId: 'bob', userName: 'Bob', shareAmount: 30),
    const ExpenseSplit(userId: 'carol', userName: 'Carol', shareAmount: 30),
  ];

  setUpAll(() {
    registerFallbackValue(FakeExpense());
  });

  setUp(() {
    mockRepo = MockExpenseRepository();
    useCase = AddExpenseUseCase(mockRepo);
    // Stub addExpense to return Right by default.
    when(() => mockRepo.addExpense(any())).thenAnswer(
      (invocation) async => Right(invocation.positionalArguments[0] as Expense),
    );
  });

  group('AddExpenseUseCase', () {
    test('calls repository.addExpense once', () async {
      await useCase(
        itineraryId: 'it-1',
        title: 'Dinner',
        amount: 90,
        currencyCode: 'USD',
        category: ExpenseCategory.food,
        payerId: 'alice',
        payerName: 'Alice',
        splits: tSplits,
      );

      verify(() => mockRepo.addExpense(any())).called(1);
    });

    test('trims whitespace from title', () async {
      await useCase(
        itineraryId: 'it-1',
        title: '  Dinner  ',
        amount: 90,
        currencyCode: 'USD',
        category: ExpenseCategory.food,
        payerId: 'alice',
        payerName: 'Alice',
        splits: tSplits,
      );

      final captured =
          verify(() => mockRepo.addExpense(captureAny())).captured;
      final expense = captured.first as Expense;
      expect(expense.title, 'Dinner');
    });

    test('expense id is a non-empty UUID string', () async {
      await useCase(
        itineraryId: 'it-1',
        title: 'Taxi',
        amount: 20,
        currencyCode: 'USD',
        category: ExpenseCategory.transport,
        payerId: 'alice',
        payerName: 'Alice',
        splits: [],
      );

      final captured =
          verify(() => mockRepo.addExpense(captureAny())).captured;
      final expense = captured.first as Expense;
      expect(expense.id, isNotEmpty);
      // Basic UUID format check: 36 chars with dashes
      expect(expense.id.length, 36);
    });

    test('createdAt is set to a UTC time close to now', () async {
      final before = DateTime.now().toUtc();

      await useCase(
        itineraryId: 'it-1',
        title: 'Coffee',
        amount: 5,
        currencyCode: 'USD',
        category: ExpenseCategory.food,
        payerId: 'alice',
        payerName: 'Alice',
        splits: [],
      );

      final after = DateTime.now().toUtc();
      final captured =
          verify(() => mockRepo.addExpense(captureAny())).captured;
      final expense = captured.first as Expense;

      expect(
        expense.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(expense.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
    });

    test('returns Right(expense) on success', () async {
      final result = await useCase(
        itineraryId: 'it-1',
        title: 'Lunch',
        amount: 45,
        currencyCode: 'JPY',
        category: ExpenseCategory.food,
        payerId: 'alice',
        payerName: 'Alice',
        splits: tSplits,
      );

      expect(result.isRight(), isTrue);
    });

    test('propagates ServerFailure from repository', () async {
      when(() => mockRepo.addExpense(any())).thenAnswer(
          (_) async => const Left(ServerFailure('DB error')));

      final result = await useCase(
        itineraryId: 'it-1',
        title: 'Lunch',
        amount: 45,
        currencyCode: 'USD',
        category: ExpenseCategory.food,
        payerId: 'alice',
        payerName: 'Alice',
        splits: tSplits,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
