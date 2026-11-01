import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/date_utils.dart';
import 'package:joint_expenses/data/models/transaction_type.dart';
import 'package:joint_expenses/features/transactions/domain/transaction_filter.dart';

import '../helpers/fixtures.dart';

void main() {
  final all = Fixtures.specExample();

  group('TransactionFilter.apply', () {
    test('no filter returns everything newest first', () {
      final result = const TransactionFilter().apply(all);
      expect(result.length, all.length);
      expect(result.first.id, 't6');
      expect(result.last.transactionDate, Fixtures.nov1);
    });

    test('oldest first sorting', () {
      final result = const TransactionFilter(sort: TransactionSort.oldestFirst).apply(all);
      expect(result.first.transactionDate, Fixtures.nov1);
      expect(result.last.id, 't6');
    });

    test('filters by type', () {
      final income = const TransactionFilter(type: TransactionType.income).apply(all);
      expect(income.map((t) => t.id), containsAll(['t1', 't2']));
      expect(income.length, 2);

      final expenses = const TransactionFilter(type: TransactionType.expense).apply(all);
      expect(expenses.length, 4);
    });

    test('filters by category and user', () {
      final food = const TransactionFilter(categoryId: 'cat-food').apply(all);
      expect(food.length, 2);

      final user2 = const TransactionFilter(userId: Fixtures.user2).apply(all);
      expect(user2.map((t) => t.id), containsAll(['t2', 't5', 't6']));
      expect(user2.length, 3);
    });

    test('filters by month', () {
      final nov = TransactionFilter(month: const YearMonth(2026, 11)).apply(all);
      expect(nov.length, all.length);
      final oct = TransactionFilter(month: const YearMonth(2026, 10)).apply(all);
      expect(oct, isEmpty);
    });

    test('search matches description, category and member name (case-insensitive)', () {
      expect(const TransactionFilter(query: 'grocer').apply(all).single.id, 't4');
      expect(const TransactionFilter(query: 'RENT').apply(all).single.id, 't3');
      expect(const TransactionFilter(query: 'alex').apply(all).length, 3);
      expect(const TransactionFilter(query: 'zzz').apply(all), isEmpty);
    });

    test('hasActiveFilters ignores month and sort', () {
      expect(TransactionFilter.initial().hasActiveFilters, isFalse);
      expect(const TransactionFilter(type: TransactionType.income).hasActiveFilters, isTrue);
      expect(const TransactionFilter(query: ' ').hasActiveFilters, isFalse);
    });

    test('copyWith clear flags reset fields', () {
      const filter = TransactionFilter(type: TransactionType.income, categoryId: 'x', userId: 'u');
      final cleared = filter.copyWith(clearType: true, clearCategory: true, clearUser: true);
      expect(cleared.type, isNull);
      expect(cleared.categoryId, isNull);
      expect(cleared.userId, isNull);
      expect(filter.cleared().hasActiveFilters, isFalse);
    });
  });

  group('groupByDate', () {
    test('groups a sorted list by calendar day preserving order', () {
      final sorted = const TransactionFilter().apply(all);
      final groups = groupByDate(sorted);
      expect(groups.map((g) => g.date), [
        Fixtures.nov12,
        Fixtures.nov10,
        Fixtures.nov5,
        Fixtures.nov1,
      ]);
      expect(groups[1].items.length, 2);
      expect(groups.last.items.length, 2);
    });

    test('labels today and yesterday', () {
      final now = DateTime(2026, 11, 12, 9);
      final sorted = const TransactionFilter().apply(all);
      final groups = groupByDate(sorted);
      expect(groups[0].label(now: now), 'Today');
      expect(AppDateUtils.groupLabel(DateTime(2026, 11, 11), now: now), 'Yesterday');
      expect(groups[1].label(now: now), 'Tuesday, 10 Nov');
      expect(AppDateUtils.groupLabel(DateTime(2025, 12, 25), now: now), '25 Dec 2025');
    });

    test('empty list yields no groups', () {
      expect(groupByDate(const []), isEmpty);
    });
  });

  group('YearMonth', () {
    test('navigates across year boundaries', () {
      expect(const YearMonth(2026, 1).previous, const YearMonth(2025, 12));
      expect(const YearMonth(2026, 12).next, const YearMonth(2027, 1));
    });

    test('provides inclusive ISO bounds for SQL', () {
      const feb = YearMonth(2028, 2); // leap year
      expect(feb.startIso, '2028-02-01');
      expect(feb.endIso, '2028-02-29');
    });

    test('contains checks year and month', () {
      const m = YearMonth(2026, 11);
      expect(m.contains(DateTime(2026, 11, 30)), isTrue);
      expect(m.contains(DateTime(2026, 12, 1)), isFalse);
    });
  });
}
