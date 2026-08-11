import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';

void main() {
  group('ExpenseSummary.adjustedBy', () {
    test('a positive delta (adding an expense) increases the total and the '
        'category', () {
      const summary = ExpenseSummary(
        totalSpent: 100,
        spentByCategory: {'food': 40, 'transport': 60},
        memberBalances: {'user-1': 10},
      );

      final result = summary.adjustedBy(categoryKey: 'food', delta: 25);

      expect(result.totalSpent, 125);
      expect(result.spentByCategory, {'food': 65, 'transport': 60});
      // Member balances are untouched by this adjustment.
      expect(result.memberBalances, summary.memberBalances);
    });

    test('a negative delta (removing an expense) decreases the total and '
        'the category', () {
      const summary = ExpenseSummary(
        totalSpent: 100,
        spentByCategory: {'food': 40, 'transport': 60},
        memberBalances: {},
      );

      final result = summary.adjustedBy(categoryKey: 'transport', delta: -60);

      expect(result.totalSpent, 40);
      expect(result.spentByCategory, {'food': 40, 'transport': 0});
    });

    test('clamps the total and the category to zero instead of going '
        'negative', () {
      const summary = ExpenseSummary(
        totalSpent: 10,
        spentByCategory: {'food': 10},
        memberBalances: {},
      );

      final result = summary.adjustedBy(categoryKey: 'food', delta: -50);

      expect(result.totalSpent, 0);
      expect(result.spentByCategory, {'food': 0});
    });

    test('adding to a category with no prior spend starts it at the delta', () {
      const summary = ExpenseSummary(
        totalSpent: 50,
        spentByCategory: {'food': 50},
        memberBalances: {},
      );

      final result = summary.adjustedBy(categoryKey: 'transport', delta: 30);

      expect(result.totalSpent, 80);
      expect(result.spentByCategory, {'food': 50, 'transport': 30});
    });

    test('does not mutate the original summary\'s category map', () {
      const summary = ExpenseSummary(
        totalSpent: 100,
        spentByCategory: {'food': 40},
        memberBalances: {},
      );

      summary.adjustedBy(categoryKey: 'food', delta: 10);

      expect(summary.spentByCategory, {'food': 40});
    });
  });
}
