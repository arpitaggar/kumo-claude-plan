import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/expense_split/domain/entities/expense.dart';
import 'package:kumo_claude/features/expense_split/domain/usecases/calculate_settlements_usecase.dart';

void main() {
  late CalculateSettlementsUseCase useCase;

  setUp(() {
    useCase = const CalculateSettlementsUseCase();
  });

  Expense makeExpense({
    required String payerId,
    required String payerName,
    required double amount,
    required List<ExpenseSplit> splits,
  }) =>
      Expense(
        id: 'e-$payerId',
        itineraryId: 'itinerary-1',
        title: 'Test expense',
        amount: amount,
        currencyCode: 'USD',
        category: ExpenseCategory.other,
        payerId: payerId,
        payerName: payerName,
        splits: splits,
        createdAt: DateTime(2026),
      );

  group('empty / trivial cases', () {
    test('returns empty list for no expenses', () {
      expect(useCase([]), isEmpty);
    });

    test('returns empty list when payer is the only member (no splits)', () {
      final expense = makeExpense(
        payerId: 'alice',
        payerName: 'Alice',
        amount: 30,
        splits: [],
      );
      expect(useCase([expense]), isEmpty);
    });
  });

  group('two-person scenarios', () {
    test('one expense: debtor owes payer the share amount', () {
      final expense = makeExpense(
        payerId: 'alice',
        payerName: 'Alice',
        amount: 100,
        splits: [
          const ExpenseSplit(
              userId: 'bob', userName: 'Bob', shareAmount: 50),
        ],
      );

      final settlements = useCase([expense]);

      expect(settlements, hasLength(1));
      expect(settlements.first.fromUserId, 'bob');
      expect(settlements.first.toUserId, 'alice');
      expect(settlements.first.amount, 50.0);
    });

    test('two expenses: net balance is calculated correctly', () {
      // Alice paid 60 for Bob; Bob paid 20 for Alice.
      // Net: Bob owes 60-20 = 40 to Alice.
      final expenses = [
        makeExpense(
          payerId: 'alice',
          payerName: 'Alice',
          amount: 60,
          splits: [
            const ExpenseSplit(
                userId: 'bob', userName: 'Bob', shareAmount: 60),
          ],
        ),
        makeExpense(
          payerId: 'bob',
          payerName: 'Bob',
          amount: 20,
          splits: [
            const ExpenseSplit(
                userId: 'alice', userName: 'Alice', shareAmount: 20),
          ],
        ),
      ];

      final settlements = useCase(expenses);

      expect(settlements, hasLength(1));
      expect(settlements.first.fromUserId, 'bob');
      expect(settlements.first.toUserId, 'alice');
      expect(settlements.first.amount, 40.0);
    });

    test('amounts round to two decimal places', () {
      // 100 / 3 = 33.333... each — rounded to 33.33
      final expense = makeExpense(
        payerId: 'alice',
        payerName: 'Alice',
        amount: 100,
        splits: [
          const ExpenseSplit(
              userId: 'bob', userName: 'Bob', shareAmount: 33.33),
        ],
      );

      final settlements = useCase([expense]);

      expect(settlements.first.amount, 33.33);
    });
  });

  group('three-person scenarios', () {
    test('one expense paid by Alice, split equally', () {
      // Alice paid 90; Bob and Carol each owe 30.
      final expense = makeExpense(
        payerId: 'alice',
        payerName: 'Alice',
        amount: 90,
        splits: [
          const ExpenseSplit(
              userId: 'bob', userName: 'Bob', shareAmount: 30),
          const ExpenseSplit(
              userId: 'carol', userName: 'Carol', shareAmount: 30),
        ],
      );

      final settlements = useCase([expense]);

      expect(settlements, hasLength(2));
      final toAlice = settlements.where((s) => s.toUserId == 'alice').toList();
      expect(toAlice, hasLength(2));
      for (final s in toAlice) {
        expect(s.amount, 30.0);
      }
    });

    test('greedy minimisation: two debtors, one creditor', () {
      // Alice paid 90 total (30 each for Bob and Carol).
      // Bob paid 10 for Alice, Carol paid 5 for Alice.
      // Net: Alice +45, Bob -20, Carol -25.
      final expenses = [
        makeExpense(
          payerId: 'alice',
          payerName: 'Alice',
          amount: 90,
          splits: [
            const ExpenseSplit(
                userId: 'bob', userName: 'Bob', shareAmount: 30),
            const ExpenseSplit(
                userId: 'carol', userName: 'Carol', shareAmount: 30),
          ],
        ),
        makeExpense(
          payerId: 'bob',
          payerName: 'Bob',
          amount: 10,
          splits: [
            const ExpenseSplit(
                userId: 'alice', userName: 'Alice', shareAmount: 10),
          ],
        ),
        makeExpense(
          payerId: 'carol',
          payerName: 'Carol',
          amount: 5,
          splits: [
            const ExpenseSplit(
                userId: 'alice', userName: 'Alice', shareAmount: 5),
          ],
        ),
      ];

      final settlements = useCase(expenses);

      // Total owed to Alice = 45.  Bob net owes 20; Carol net owes 25.
      expect(settlements, hasLength(2));
      final totalPaid =
          settlements.fold<double>(0, (sum, s) => sum + s.amount);
      expect(totalPaid, closeTo(45.0, 0.01));
    });

    test('returns empty when balances cancel out exactly', () {
      // Alice→Bob 50, Bob→Carol 50, Carol→Alice 50: all square.
      final expenses = [
        makeExpense(
          payerId: 'alice',
          payerName: 'Alice',
          amount: 50,
          splits: [
            const ExpenseSplit(
                userId: 'bob', userName: 'Bob', shareAmount: 50),
          ],
        ),
        makeExpense(
          payerId: 'bob',
          payerName: 'Bob',
          amount: 50,
          splits: [
            const ExpenseSplit(
                userId: 'carol', userName: 'Carol', shareAmount: 50),
          ],
        ),
        makeExpense(
          payerId: 'carol',
          payerName: 'Carol',
          amount: 50,
          splits: [
            const ExpenseSplit(
                userId: 'alice', userName: 'Alice', shareAmount: 50),
          ],
        ),
      ];

      expect(useCase(expenses), isEmpty);
    });
  });

  group('settlement properties', () {
    test('fromUserId is always the debtor', () {
      final expense = makeExpense(
        payerId: 'alice',
        payerName: 'Alice',
        amount: 60,
        splits: [
          const ExpenseSplit(
              userId: 'bob', userName: 'Bob', shareAmount: 60),
        ],
      );

      final settlements = useCase([expense]);

      for (final s in settlements) {
        expect(s.fromUserId, isNot(s.toUserId));
        expect(s.amount, isPositive);
      }
    });

    test('settlement amounts are all positive', () {
      final expenses = [
        makeExpense(
          payerId: 'alice',
          payerName: 'Alice',
          amount: 90,
          splits: [
            const ExpenseSplit(
                userId: 'bob', userName: 'Bob', shareAmount: 45),
            const ExpenseSplit(
                userId: 'carol', userName: 'Carol', shareAmount: 45),
          ],
        ),
      ];

      final settlements = useCase(expenses);

      for (final s in settlements) {
        expect(s.amount, isPositive);
      }
    });
  });
}
