import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/money.dart';
import 'package:joint_expenses/data/models/expense_scope.dart';
import 'package:joint_expenses/data/models/joint_budget_share.dart';
import 'package:joint_expenses/features/dashboard/domain/joint_budget.dart';

import '../helpers/fixtures.dart';

void main() {
  group('JointBudgetCalculator', () {
    test('ignores personal income and expenses', () {
      final budget = JointBudgetCalculator.compute(
        transactions: Fixtures.specExample(),
        shares: const [],
        currentUserId: Fixtures.user1,
      );

      expect(budget.leftover, Money.zero);
      expect(budget.jointIncome, Money.zero);
      expect(budget.jointExpense, Money.zero);
      expect(budget.personalLeftover, Money.parse('30000'));
    });

    test('carries unused joint leftover across months', () {
      final budget = JointBudgetCalculator.compute(
        transactions: [
          Fixtures.tx(
            id: 'i1',
            userId: Fixtures.user1,
            category: Fixtures.salary,
            amount: '15000',
            date: DateTime(2026, 10, 1),
            expenseScope: ExpenseScope.joint,
          ),
          Fixtures.tx(
            id: 'i2',
            userId: Fixtures.user2,
            category: Fixtures.salary,
            amount: '15000',
            date: DateTime(2026, 10, 1),
            expenseScope: ExpenseScope.joint,
          ),
          Fixtures.tx(
            id: 'e1',
            userId: Fixtures.user1,
            category: Fixtures.rent,
            amount: '10000',
            date: DateTime(2026, 11, 5),
            expenseScope: ExpenseScope.joint,
          ),
        ],
        shares: const [],
        currentUserId: Fixtures.user1,
      );

      expect(budget.leftover, Money.parse('20000'));
      expect(budget.isUnused, isTrue);
    });

    test('share adjustment resets a negative leftover to zero', () {
      final share = JointBudgetShare(
        id: 's1',
        householdId: Fixtures.householdId,
        adjustmentAmount: Money.fromUnits(5000),
        leftoverBefore: Money.fromMinor(-500000),
        sharedAt: DateTime(2026, 11, 2),
        markedBy: Fixtures.user1,
      );
      final budget = JointBudgetCalculator.compute(
        transactions: [
          Fixtures.tx(
            id: 'e1',
            userId: Fixtures.user1,
            category: Fixtures.rent,
            amount: '5000',
            date: DateTime(2026, 11, 1),
            expenseScope: ExpenseScope.joint,
          ),
        ],
        shares: [share],
        currentUserId: Fixtures.user1,
      );

      expect(budget.leftover, Money.zero);
      expect(budget.isReset, isTrue);
      expect(budget.lastShare, share);
    });

    test('later joint contributions rebuild the pot after a share', () {
      final share = JointBudgetShare(
        id: 's1',
        householdId: Fixtures.householdId,
        adjustmentAmount: Money.fromUnits(5000),
        leftoverBefore: Money.fromMinor(-500000),
        sharedAt: DateTime(2026, 11, 2),
        markedBy: Fixtures.user1,
      );
      final budget = JointBudgetCalculator.compute(
        transactions: [
          Fixtures.tx(
            id: 'e1',
            userId: Fixtures.user1,
            category: Fixtures.rent,
            amount: '5000',
            date: DateTime(2026, 11, 1),
            expenseScope: ExpenseScope.joint,
          ),
          Fixtures.tx(
            id: 'i1',
            userId: Fixtures.user1,
            category: Fixtures.salary,
            amount: '15000',
            date: DateTime(2026, 12, 1),
            expenseScope: ExpenseScope.joint,
          ),
          Fixtures.tx(
            id: 'i2',
            userId: Fixtures.user2,
            category: Fixtures.salary,
            amount: '15000',
            date: DateTime(2026, 12, 1),
            expenseScope: ExpenseScope.joint,
          ),
        ],
        shares: [share],
        currentUserId: Fixtures.user1,
      );

      expect(budget.leftover, Money.parse('30000'));
    });
  });
}
