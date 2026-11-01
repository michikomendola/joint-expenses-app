import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';

/// Per-member totals for a period.
@immutable
class MemberTotal {
  const MemberTotal({
    required this.userId,
    required this.displayName,
    required this.income,
    required this.expense,
  });

  final String userId;
  final String displayName;
  final Money income;
  final Money expense;

  Money get net => income - expense;

  @override
  bool operator ==(Object other) =>
      other is MemberTotal &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.income == income &&
      other.expense == expense;

  @override
  int get hashCode => Object.hash(userId, displayName, income, expense);
}

/// One slice of the spending donut.
@immutable
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.amount,
    required this.percentage,
    required this.count,
  });

  final String categoryId;
  final String name;
  final String icon;
  final String colorHex;
  final Money amount;

  /// 0..100, already rounded to one decimal place.
  final double percentage;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is CategorySlice &&
      other.categoryId == categoryId &&
      other.amount == amount &&
      other.percentage == percentage &&
      other.count == count;

  @override
  int get hashCode => Object.hash(categoryId, amount, percentage, count);
}

/// Everything the dashboard needs for the selected period.
@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.memberTotals,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.recent,
    required this.transactionCount,
  });

  static const DashboardSummary empty = DashboardSummary(
    totalIncome: Money.zero,
    totalExpense: Money.zero,
    memberTotals: [],
    expenseByCategory: [],
    incomeByCategory: [],
    recent: [],
    transactionCount: 0,
  );

  final Money totalIncome;
  final Money totalExpense;
  final List<MemberTotal> memberTotals;

  /// Sorted by amount, descending.
  final List<CategorySlice> expenseByCategory;
  final List<CategorySlice> incomeByCategory;

  /// Latest transactions (max 5), newest first.
  final List<TransactionModel> recent;
  final int transactionCount;

  /// Remaining Balance = Total Income − Total Expenses.
  Money get balance => totalIncome - totalExpense;

  bool get isEmpty => transactionCount == 0;

  /// Share of income that has been spent (0..1, capped at 1 for the bar).
  double get spentRatio {
    if (totalIncome.isZero) return totalExpense.isZero ? 0 : 1;
    final ratio = totalExpense.ratioOf(totalIncome);
    return ratio.clamp(0, 1).toDouble();
  }

  CategorySlice? sliceFor(String categoryId) {
    for (final slice in expenseByCategory) {
      if (slice.categoryId == categoryId) return slice;
    }
    for (final slice in incomeByCategory) {
      if (slice.categoryId == categoryId) return slice;
    }
    return null;
  }
}

/// Pure calculations – covered by unit tests.
abstract final class DashboardCalculator {
  static DashboardSummary compute({
    required List<TransactionModel> transactions,
    required Map<String, CategoryModel> categories,
    Map<String, String> memberNames = const {},
    int recentCount = 5,
  }) {
    if (transactions.isEmpty) return DashboardSummary.empty;

    var totalIncome = Money.zero;
    var totalExpense = Money.zero;
    final incomeByUser = <String, Money>{};
    final expenseByUser = <String, Money>{};
    final expenseByCategory = <String, Money>{};
    final incomeByCategory = <String, Money>{};
    final countByCategory = <String, int>{};
    final namesSeen = <String, String>{...memberNames};

    for (final t in transactions) {
      if (t.userDisplayName != null && !namesSeen.containsKey(t.userId)) {
        namesSeen[t.userId] = t.userDisplayName!;
      }
      countByCategory[t.categoryId] = (countByCategory[t.categoryId] ?? 0) + 1;

      if (t.isIncome) {
        totalIncome += t.amount;
        incomeByUser[t.userId] = (incomeByUser[t.userId] ?? Money.zero) + t.amount;
        incomeByCategory[t.categoryId] =
            (incomeByCategory[t.categoryId] ?? Money.zero) + t.amount;
      } else {
        totalExpense += t.amount;
        expenseByUser[t.userId] = (expenseByUser[t.userId] ?? Money.zero) + t.amount;
        expenseByCategory[t.categoryId] =
            (expenseByCategory[t.categoryId] ?? Money.zero) + t.amount;
      }
    }

    final userIds = <String>{
      ...memberNames.keys,
      ...incomeByUser.keys,
      ...expenseByUser.keys,
    };
    final memberTotals = userIds
        .map(
          (id) => MemberTotal(
            userId: id,
            displayName: namesSeen[id] ?? 'Member',
            income: incomeByUser[id] ?? Money.zero,
            expense: expenseByUser[id] ?? Money.zero,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    final sorted = [...transactions]..sort(_newestFirst);

    return DashboardSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      memberTotals: memberTotals,
      expenseByCategory: _slices(
        totals: expenseByCategory,
        counts: countByCategory,
        grandTotal: totalExpense,
        categories: categories,
        transactions: transactions,
      ),
      incomeByCategory: _slices(
        totals: incomeByCategory,
        counts: countByCategory,
        grandTotal: totalIncome,
        categories: categories,
        transactions: transactions,
      ),
      recent: sorted.take(recentCount).toList(growable: false),
      transactionCount: transactions.length,
    );
  }

  static int _newestFirst(TransactionModel a, TransactionModel b) {
    final byDate = b.transactionDate.compareTo(a.transactionDate);
    if (byDate != 0) return byDate;
    final aCreated = a.createdAt ?? a.transactionDate;
    final bCreated = b.createdAt ?? b.transactionDate;
    return bCreated.compareTo(aCreated);
  }

  static List<CategorySlice> _slices({
    required Map<String, Money> totals,
    required Map<String, int> counts,
    required Money grandTotal,
    required Map<String, CategoryModel> categories,
    required List<TransactionModel> transactions,
  }) {
    final slices = totals.entries.map((entry) {
      // Prefer the shared category list; fall back to the category embedded
      // in a transaction so deleted/unknown ids still render sensibly.
      final category = categories[entry.key] ??
          transactions
              .firstWhere((t) => t.categoryId == entry.key)
              .category;
      final percentage = grandTotal.isZero
          ? 0.0
          : (entry.value.percentOf(grandTotal) * 10).round() / 10;
      return CategorySlice(
        categoryId: entry.key,
        name: category?.name ?? 'Others',
        icon: category?.icon ?? 'category',
        colorHex: category?.color ?? '#64748B',
        amount: entry.value,
        percentage: percentage,
        count: counts[entry.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) {
        final byAmount = b.amount.compareTo(a.amount);
        return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
      });
    return slices;
  }
}
