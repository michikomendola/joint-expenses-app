import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../categories/application/category_providers.dart';
import '../../households/application/household_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../domain/dashboard_summary.dart';

/// Month shown on the dashboard and categories screen.
final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, YearMonth>(SelectedMonthNotifier.new);

class SelectedMonthNotifier extends Notifier<YearMonth> {
  @override
  YearMonth build() => YearMonth.now();

  void select(YearMonth month) => state = month;
  void previous() => state = state.previous;
  void next() => state = state.next;
  void reset() => state = YearMonth.now();
}

/// Derived summary for the selected month. Recomputes whenever transactions,
/// categories or member names change (including realtime updates).
final dashboardSummaryProvider = Provider<AsyncValue<DashboardSummary>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final transactions = ref.watch(monthTransactionsProvider(month));
  final categoriesAsync = ref.watch(categoriesProvider);
  final memberNames = ref.watch(memberNamesProvider);

  // Surface category loading errors but don't block on them: the summary can
  // still be computed with the categories embedded in each transaction.
  if (transactions.isLoading && !transactions.hasValue) {
    return const AsyncLoading();
  }
  if (transactions.hasError && !transactions.hasValue) {
    return AsyncError(transactions.error!, transactions.stackTrace!);
  }
  if (categoriesAsync.isLoading && !categoriesAsync.hasValue) {
    return const AsyncLoading();
  }

  final categories = ref.watch(categoryMapProvider);
  final summary = DashboardCalculator.compute(
    transactions: transactions.value ?? const [],
    categories: categories,
    memberNames: memberNames,
    recentCount: AppConstants.recentTransactionsCount,
  );
  return AsyncData(summary);
});
