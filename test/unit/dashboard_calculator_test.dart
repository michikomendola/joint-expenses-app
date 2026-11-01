import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/money.dart';
import 'package:joint_expenses/features/dashboard/domain/dashboard_summary.dart';

import '../helpers/fixtures.dart';

void main() {
  group('DashboardCalculator', () {
    test('matches the specification example', () {
      final summary = DashboardCalculator.compute(
        transactions: Fixtures.specExample(),
        categories: Fixtures.categoryMap,
        memberNames: Fixtures.memberNames,
      );

      expect(summary.totalIncome, Money.parse('75000'));
      expect(summary.totalExpense, Money.parse('25000'));
      expect(summary.balance, Money.parse('50000'));
      expect(summary.transactionCount, 6);
    });

    test('computes individual income and expenses per member', () {
      final summary = DashboardCalculator.compute(
        transactions: Fixtures.specExample(),
        categories: Fixtures.categoryMap,
        memberNames: Fixtures.memberNames,
      );

      final byId = {for (final m in summary.memberTotals) m.userId: m};
      expect(byId[Fixtures.user1]!.income, Money.parse('45000'));
      expect(byId[Fixtures.user1]!.expense, Money.parse('15000'));
      expect(byId[Fixtures.user2]!.income, Money.parse('30000'));
      expect(byId[Fixtures.user2]!.expense, Money.parse('10000'));
      expect(byId[Fixtures.user1]!.displayName, 'Michiko');
    });

    test('counts an expense once regardless of who paid', () {
      final summary = DashboardCalculator.compute(
        transactions: Fixtures.specExample(),
        categories: Fixtures.categoryMap,
      );
      // 10000 + 5000 + 7500 + 2500 – no splitting, no double counting.
      expect(summary.totalExpense, Money.parse('25000'));
    });

    test('groups expenses by category with percentages sorted descending', () {
      final summary = DashboardCalculator.compute(
        transactions: Fixtures.specExample(),
        categories: Fixtures.categoryMap,
      );

      expect(summary.expenseByCategory.map((s) => s.name).toList(),
          ['Food & Drinks', 'Rent', 'Transportation']);

      final food = summary.expenseByCategory[0];
      expect(food.amount, Money.parse('12500'));
      expect(food.percentage, 50.0);
      expect(food.count, 2);

      final rent = summary.expenseByCategory[1];
      expect(rent.amount, Money.parse('10000'));
      expect(rent.percentage, 40.0);

      final transport = summary.expenseByCategory[2];
      expect(transport.percentage, 10.0);

      final total = summary.expenseByCategory.fold<double>(0, (a, s) => a + s.percentage);
      expect(total, closeTo(100, 0.2));
    });

    test('income is grouped by category too', () {
      final summary = DashboardCalculator.compute(
        transactions: Fixtures.specExample(),
        categories: Fixtures.categoryMap,
      );
      expect(summary.incomeByCategory.single.name, 'Salary');
      expect(summary.incomeByCategory.single.amount, Money.parse('75000'));
      expect(summary.incomeByCategory.single.percentage, 100);
    });

    test('returns the latest five transactions newest first', () {
      final summary = DashboardCalculator.compute(
        transactions: Fixtures.specExample(),
        categories: Fixtures.categoryMap,
      );
      expect(summary.recent.length, 5);
      expect(summary.recent.first.id, 't6');
      expect(summary.recent.map((t) => t.id).contains('t2'), isFalse,
          reason: 'oldest (same-day, earlier) record is dropped');
    });

    test('empty input yields an empty summary without division errors', () {
      final summary = DashboardCalculator.compute(
        transactions: const [],
        categories: Fixtures.categoryMap,
      );
      expect(summary, DashboardSummary.empty);
      expect(summary.balance, Money.zero);
      expect(summary.spentRatio, 0);
      expect(summary.expenseByCategory, isEmpty);
    });

    test('handles zero expenses with income present', () {
      final summary = DashboardCalculator.compute(
        transactions: [
          Fixtures.tx(
            id: 'only',
            userId: Fixtures.user1,
            category: Fixtures.salary,
            amount: '1000',
            date: Fixtures.nov1,
          ),
        ],
        categories: Fixtures.categoryMap,
      );
      expect(summary.totalExpense, Money.zero);
      expect(summary.expenseByCategory, isEmpty);
      expect(summary.spentRatio, 0);
      expect(summary.balance, Money.parse('1000'));
    });

    test('negative balance when expenses exceed income', () {
      final summary = DashboardCalculator.compute(
        transactions: [
          Fixtures.tx(id: 'a', userId: Fixtures.user1, category: Fixtures.rent, amount: '2000', date: Fixtures.nov1),
          Fixtures.tx(id: 'b', userId: Fixtures.user1, category: Fixtures.salary, amount: '500', date: Fixtures.nov1),
        ],
        categories: Fixtures.categoryMap,
      );
      expect(summary.balance, Money.parse('-1500'));
      expect(summary.spentRatio, 1, reason: 'capped for the progress bar');
    });

    test('falls back to the embedded category when the shared list is missing it', () {
      final summary = DashboardCalculator.compute(
        transactions: Fixtures.specExample(),
        categories: const {}, // nothing loaded yet
      );
      expect(summary.expenseByCategory.first.name, 'Food & Drinks');
      expect(summary.expenseByCategory.first.colorHex, '#F97316');
    });

    test('member totals include members with no transactions', () {
      final summary = DashboardCalculator.compute(
        transactions: [
          Fixtures.tx(id: 'a', userId: Fixtures.user1, category: Fixtures.salary, amount: '100', date: Fixtures.nov1),
        ],
        categories: Fixtures.categoryMap,
        memberNames: Fixtures.memberNames,
      );
      final alex = summary.memberTotals.firstWhere((m) => m.userId == Fixtures.user2);
      expect(alex.income, Money.zero);
      expect(alex.expense, Money.zero);
    });
  });
}
