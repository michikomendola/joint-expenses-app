import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../authentication/application/auth_providers.dart';
import '../../categories/application/category_providers.dart';
import '../../households/application/household_providers.dart';
import '../domain/transaction_filter.dart';

/// Transactions of the active household for a month (`null` = all time).
/// Kept alive so the dashboard and the list share one fetch per month; the
/// realtime sync invalidates the whole family on any change.
final monthTransactionsProvider =
    FutureProvider.family<List<TransactionModel>, YearMonth?>((ref, month) async {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return const [];
  return ref.watch(transactionRepositoryProvider).fetch(
        householdId: householdId,
        month: month,
      );
});

/// Filter state for the Transactions screen.
final transactionFilterProvider =
    NotifierProvider<TransactionFilterNotifier, TransactionFilter>(
  TransactionFilterNotifier.new,
);

class TransactionFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => TransactionFilter.initial();

  void update(TransactionFilter Function(TransactionFilter current) updater) {
    state = updater(state);
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void setMonth(YearMonth? month) =>
      state = month == null ? state.copyWith(clearMonth: true) : state.copyWith(month: month);

  void toggleSort() => state = state.copyWith(
        sort: state.sort == TransactionSort.newestFirst
            ? TransactionSort.oldestFirst
            : TransactionSort.newestFirst,
      );

  void clear() => state = state.cleared();
}

/// Filtered + sorted transactions for the Transactions screen.
final filteredTransactionsProvider = Provider<AsyncValue<List<TransactionModel>>>((ref) {
  final filter = ref.watch(transactionFilterProvider);
  final source = ref.watch(monthTransactionsProvider(filter.month));
  return source.whenData(filter.apply);
});

/// Grouped by day for rendering.
final groupedTransactionsProvider = Provider<AsyncValue<List<TransactionGroup>>>((ref) {
  return ref.watch(filteredTransactionsProvider).whenData(groupByDate);
});

/// Create / update / delete transactions.
final transactionControllerProvider =
    AsyncNotifierProvider.autoDispose<TransactionController, void>(
  TransactionController.new,
);

class TransactionController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  TransactionRepository get _repo => ref.read(transactionRepositoryProvider);

  bool get _busy => state.isLoading;

  Future<bool> create(TransactionInput input) async {
    if (_busy) return false; // guard against double taps → duplicates
    final householdId = ref.read(currentHouseholdIdProvider);
    final userId = ref.read(currentUserIdProvider);
    if (householdId == null || userId == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.create(householdId: householdId, userId: userId, input: input),
    );
    if (!state.hasError) _refreshData();
    return !state.hasError;
  }

  Future<bool> edit(String id, TransactionInput input) async {
    if (_busy) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.update(id, input));
    if (!state.hasError) _refreshData();
    return !state.hasError;
  }

  Future<bool> delete(String id) async {
    if (_busy) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.delete(id));
    if (!state.hasError) _refreshData();
    return !state.hasError;
  }

  void _refreshData() {
    ref.invalidate(monthTransactionsProvider);
    // Category totals are derived from transactions; no category refetch needed,
    // but keep the map warm in case the list was never loaded.
    ref.read(categoriesProvider);
  }
}
