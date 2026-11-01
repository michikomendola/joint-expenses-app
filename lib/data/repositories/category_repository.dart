import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../services/supabase_service.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(supabaseClientProvider));
});

class CategoryRepository {
  CategoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<CategoryModel>> fetchAll(String householdId) async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('household_id', householdId)
        .order('type')
        .order('name');
    return rows.map(CategoryModel.fromJson).toList(growable: false);
  }

  Future<CategoryModel> create(String householdId, CategoryInput input) async {
    final row = await _client
        .from('categories')
        .insert(input.toInsertJson(householdId))
        .select()
        .single();
    return CategoryModel.fromJson(row);
  }

  Future<CategoryModel> update(String id, CategoryInput input) async {
    final row = await _client
        .from('categories')
        .update(input.toUpdateJson())
        .eq('id', id)
        .select()
        .single();
    return CategoryModel.fromJson(row);
  }

  /// Number of transactions (all time) that reference the category.
  Future<int> countUsage(String categoryId) async {
    final response = await _client
        .from('transactions')
        .select('id')
        .eq('category_id', categoryId)
        .count(CountOption.exact);
    return response.count;
  }

  /// Deletes the category, moving existing transactions to [replacementId]
  /// first when provided. Executed server-side (RPC) so partner transactions
  /// can be re-pointed despite per-user RLS.
  Future<void> delete(String categoryId, {String? replacementId}) {
    return _client.rpc<void>(
      'reassign_and_delete_category',
      params: {
        'p_category_id': categoryId,
        'p_replacement_id': replacementId,
      },
    );
  }
}
