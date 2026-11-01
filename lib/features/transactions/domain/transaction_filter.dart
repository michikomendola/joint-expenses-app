import 'package:flutter/foundation.dart';

import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/transaction_type.dart';

enum TransactionSort { newestFirst, oldestFirst }

/// Filter state for the Transactions screen. Pure and testable.
@immutable
class TransactionFilter {
  const TransactionFilter({
    this.type,
    this.categoryId,
    this.userId,
    this.month,
    this.query = '',
    this.sort = TransactionSort.newestFirst,
  });

  factory TransactionFilter.initial() => TransactionFilter(month: YearMonth.now());

  /// null → all types.
  final TransactionType? type;
  final String? categoryId;
  final String? userId;

  /// null → all time.
  final YearMonth? month;
  final String query;
  final TransactionSort sort;

  bool get hasActiveFilters =>
      type != null || categoryId != null || userId != null || query.trim().isNotEmpty;

  TransactionFilter copyWith({
    TransactionType? type,
    bool clearType = false,
    String? categoryId,
    bool clearCategory = false,
    String? userId,
    bool clearUser = false,
    YearMonth? month,
    bool clearMonth = false,
    String? query,
    TransactionSort? sort,
  }) {
    return TransactionFilter(
      type: clearType ? null : (type ?? this.type),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      userId: clearUser ? null : (userId ?? this.userId),
      month: clearMonth ? null : (month ?? this.month),
      query: query ?? this.query,
      sort: sort ?? this.sort,
    );
  }

  TransactionFilter cleared() =>
      TransactionFilter(month: month, sort: sort);

  /// Applies type/category/user/search filters and sorting. The month is
  /// applied at query time (server-side), but is also honoured here so the
  /// function is self-contained for tests.
  List<TransactionModel> apply(Iterable<TransactionModel> source) {
    final needle = query.trim().toLowerCase();
    final result = source.where((t) {
      if (type != null && t.type != type) return false;
      if (categoryId != null && t.categoryId != categoryId) return false;
      if (userId != null && t.userId != userId) return false;
      if (month != null && !month!.contains(t.transactionDate)) return false;
      if (needle.isNotEmpty) {
        final haystack = [
          t.description ?? '',
          t.categoryName,
          t.userDisplayName ?? '',
          t.amount.toDecimalString(),
        ].join(' ').toLowerCase();
        if (!haystack.contains(needle)) return false;
      }
      return true;
    }).toList();

    result.sort((a, b) {
      final byDate = a.transactionDate.compareTo(b.transactionDate);
      final byCreated = (a.createdAt ?? a.transactionDate)
          .compareTo(b.createdAt ?? b.transactionDate);
      final cmp = byDate != 0 ? byDate : byCreated;
      return sort == TransactionSort.newestFirst ? -cmp : cmp;
    });
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.type == type &&
      other.categoryId == categoryId &&
      other.userId == userId &&
      other.month == month &&
      other.query == query &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(type, categoryId, userId, month, query, sort);
}

/// A date header with the transactions that fall on that day.
@immutable
class TransactionGroup {
  const TransactionGroup({required this.date, required this.items});

  final DateTime date;
  final List<TransactionModel> items;

  String label({DateTime? now}) => AppDateUtils.groupLabel(date, now: now);
}

/// Groups an already-sorted list by calendar day, preserving order.
List<TransactionGroup> groupByDate(List<TransactionModel> transactions) {
  final groups = <TransactionGroup>[];
  for (final t in transactions) {
    final day = AppDateUtils.dateOnly(t.transactionDate);
    if (groups.isNotEmpty && AppDateUtils.isSameDay(groups.last.date, day)) {
      groups.last.items.add(t);
    } else {
      groups.add(TransactionGroup(date: day, items: [t]));
    }
  }
  return groups;
}
