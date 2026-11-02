import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/joint_budget_share.dart';
import '../../../data/repositories/joint_budget_repository.dart';
import '../../authentication/application/auth_providers.dart';
import '../../households/application/household_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../domain/joint_budget.dart';

final jointBudgetSharesProvider =
    FutureProvider<List<JointBudgetShare>>((ref) async {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return const [];
  return ref.watch(jointBudgetRepositoryProvider).fetchShares(householdId);
});

/// All-time leftover. Uses every transaction, not the selected month.
final jointBudgetProvider = Provider<AsyncValue<JointBudget>>((ref) {
  final transactions = ref.watch(monthTransactionsProvider(null));
  final shares = ref.watch(jointBudgetSharesProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (transactions.isLoading && !transactions.hasValue) {
    return const AsyncLoading();
  }
  if (transactions.hasError && !transactions.hasValue) {
    return AsyncError(transactions.error!, transactions.stackTrace!);
  }
  if (shares.isLoading && !shares.hasValue) {
    return const AsyncLoading();
  }
  if (shares.hasError && !shares.hasValue) {
    return AsyncError(shares.error!, shares.stackTrace!);
  }

  return AsyncData(
    JointBudgetCalculator.compute(
      transactions: transactions.value ?? const [],
      shares: shares.value ?? const [],
      currentUserId: userId,
    ),
  );
});

final jointBudgetControllerProvider =
    AsyncNotifierProvider.autoDispose<JointBudgetController, void>(
  JointBudgetController.new,
);

class JointBudgetController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  bool get _busy => state.isLoading;

  Future<bool> shareDeficit() async {
    if (_busy) return false;
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(jointBudgetRepositoryProvider).shareDeficit(householdId),
    );
    if (!state.hasError) ref.invalidate(jointBudgetSharesProvider);
    return !state.hasError;
  }

  Future<bool> undoShare(String id) async {
    if (_busy) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(jointBudgetRepositoryProvider).undoShare(id),
    );
    if (!state.hasError) ref.invalidate(jointBudgetSharesProvider);
    return !state.hasError;
  }
}
