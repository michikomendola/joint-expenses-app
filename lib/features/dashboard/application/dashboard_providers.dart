import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../authentication/application/auth_providers.dart';
import '../../categories/application/category_providers.dart';
import '../../households/application/household_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../domain/dashboard_summary.dart';
import '../domain/home_account_view.dart';
import 'account_view_provider.dart';

export 'account_view_provider.dart';

/// Period shown on the dashboard and categories screen.
/// `null` means all time, which is the default.
final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, YearMonth?>(SelectedMonthNotifier.new);

class SelectedMonthNotifier extends Notifier<YearMonth?> {
  @override
  YearMonth? build() => null;

  void select(YearMonth? month) => state = month;

  void previous() {
    final current = state;
    if (current == null) return;
    state = current.previous;
  }

  void next() {
    final current = state;
    if (current == null) return;
    state = current.next;
  }

  void reset() => state = null;
}

/// Income, expenses, and recent rows for the Home view and selected period.
/// The leftover heroes stay all-time and are not taken from this summary.
final homeSummaryProvider = Provider<AsyncValue<DashboardSummary>>((ref) {
  final view = ref.watch(homeAccountViewProvider);
  final month = ref.watch(selectedMonthProvider);
  final transactions = ref.watch(monthTransactionsProvider(month));
  final categoriesAsync = ref.watch(categoriesProvider);
  final memberNames = ref.watch(memberNamesProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (transactions.isLoading && !transactions.hasValue) {
    return const AsyncLoading();
  }
  if (transactions.hasError && !transactions.hasValue) {
    return AsyncError(transactions.error!, transactions.stackTrace!);
  }
  if (categoriesAsync.isLoading && !categoriesAsync.hasValue) {
    return const AsyncLoading();
  }

  final scoped = transactionsForHomeView(
    transactions: transactions.value ?? const [],
    view: view,
    userId: userId,
  );
  final names = view == HomeAccountView.personal && userId != null
      ? {userId: memberNames[userId] ?? 'You'}
      : memberNames;
  return AsyncData(
    DashboardCalculator.compute(
      transactions: scoped,
      categories: ref.watch(categoryMapProvider),
      memberNames: names,
      recentCount: AppConstants.recentTransactionsCount,
      attributeJointExpensesToPayer: view == HomeAccountView.joint,
    ),
  );
});

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
