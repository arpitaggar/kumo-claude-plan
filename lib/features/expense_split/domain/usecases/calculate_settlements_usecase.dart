import '../entities/expense.dart';

/// Pure computation — no repository. Converts a list of expenses into the
/// minimum set of payments needed to settle all debts.
class CalculateSettlementsUseCase {
  const CalculateSettlementsUseCase();

  List<Settlement> call(List<Expense> expenses) {
    // Compute net balance per person (userId → balance).
    // Positive = creditor (is owed money), negative = debtor (owes money).
    final people = <String, _Person>{};

    void ensure(String id, String name) {
      people.putIfAbsent(id, () => _Person(id, name));
    }

    for (final expense in expenses) {
      ensure(expense.payerId, expense.payerName);

      // Payer lent out the sum of everyone else's shares.
      final lent = expense.splits.fold<double>(0, (s, e) => s + e.shareAmount);
      people[expense.payerId]!.balance += lent;

      for (final split in expense.splits) {
        ensure(split.userId, split.userName);
        people[split.userId]!.balance -= split.shareAmount;
      }
    }

    // Greedy simplification: repeatedly match largest debtor → largest creditor.
    final debtors = people.values
        .where((p) => p.balance < -0.005)
        .map((p) => _Person(p.id, p.name)..balance = p.balance)
        .toList()
      ..sort((a, b) => a.balance.compareTo(b.balance));

    final creditors = people.values
        .where((p) => p.balance > 0.005)
        .map((p) => _Person(p.id, p.name)..balance = p.balance)
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    final settlements = <Settlement>[];

    var di = 0;
    var ci = 0;
    while (di < debtors.length && ci < creditors.length) {
      final debtor = debtors[di];
      final creditor = creditors[ci];

      final payment = debtor.balance.abs() < creditor.balance
          ? debtor.balance.abs()
          : creditor.balance;

      settlements.add(Settlement(
        fromUserId: debtor.id,
        fromUserName: debtor.name,
        toUserId: creditor.id,
        toUserName: creditor.name,
        amount: _round(payment),
      ));

      debtor.balance += payment;
      creditor.balance -= payment;

      if (debtor.balance.abs() < 0.005) {
        di++;
      }
      if (creditor.balance < 0.005) {
        ci++;
      }
    }

    return settlements;
  }

  double _round(double v) => (v * 100).round() / 100;
}

class _Person {
  _Person(this.id, this.name);
  final String id;
  final String name;
  double balance = 0;
}
