import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/category.dart';
import '../../../data/models/transaction_type.dart';
import '../../../data/repositories/category_repository.dart';
import '../../households/application/household_providers.dart';

/// All categories of the active household, sorted by type then name.
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return const [];
  return ref.watch(categoryRepositoryProvider).fetchAll(householdId);
});

/// Categories filtered by type.
final categoriesByTypeProvider =
    Provider.family<AsyncValue<List<CategoryModel>>, TransactionType>((ref, type) {
  return ref.watch(categoriesProvider).whenData(
        (all) => all.where((c) => c.type == type).toList(growable: false),
      );
});

/// id → category lookup.
final categoryMapProvider = Provider<Map<String, CategoryModel>>((ref) {
  final list = ref.watch(categoriesProvider).value ?? const [];
  return {for (final c in list) c.id: c};
});

/// Mutations for categories.
final categoryControllerProvider =
    AsyncNotifierProvider.autoDispose<CategoryController, void>(CategoryController.new);

class CategoryController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  CategoryRepository get _repo => ref.read(categoryRepositoryProvider);

  /// Returns the created category, or null on error (see [state]).
  Future<CategoryModel?> create(CategoryInput input) async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return null;
    state = const AsyncLoading();
    CategoryModel? created;
    state = await AsyncValue.guard(() async {
      created = await _repo.create(householdId, input);
    });
    if (!state.hasError) ref.invalidate(categoriesProvider);
    return state.hasError ? null : created;
  }

  /// Returns the updated category, or null on error (see [state]).
  Future<CategoryModel?> edit(String id, CategoryInput input) async {
    state = const AsyncLoading();
    CategoryModel? updated;
    state = await AsyncValue.guard(() async {
      updated = await _repo.update(id, input);
    });
    if (!state.hasError) ref.invalidate(categoriesProvider);
    return state.hasError ? null : updated;
  }

  Future<int> countUsage(String id) => _repo.countUsage(id);

  Future<bool> delete(String id, {String? replacementId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.delete(id, replacementId: replacementId),
    );
    if (!state.hasError) ref.invalidate(categoriesProvider);
    return !state.hasError;
  }
}
