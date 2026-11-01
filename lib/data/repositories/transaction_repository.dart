import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/date_utils.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseClientProvider));
});

class TransactionRepository {
  TransactionRepository(this._client);

  final SupabaseClient _client;

  static const String _select =
      '*, category:categories(*), profile:profiles(display_name)';

  /// Transactions for a household, newest first. When [month] is null all
  /// records are returned (capped by [limit]).
  Future<List<TransactionModel>> fetch({
    required String householdId,
    YearMonth? month,
    int limit = 1000,
  }) async {
    var query = _client
        .from('transactions')
        .select(_select)
        .eq('household_id', householdId);

    if (month != null) {
      query = query
          .gte('transaction_date', month.startIso)
          .lte('transaction_date', month.endIso);
    }

    final rows = await query
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map(TransactionModel.fromJson).toList(growable: false);
  }

  Future<TransactionModel> create({
    required String householdId,
    required String userId,
    required TransactionInput input,
  }) async {
    final row = await _client
        .from('transactions')
        .insert(input.toInsertJson(householdId: householdId, userId: userId))
        .select(_select)
        .single();
    return TransactionModel.fromJson(row);
  }

  Future<TransactionModel> update(String id, TransactionInput input) async {
    final row = await _client
        .from('transactions')
        .update(input.toJson())
        .eq('id', id)
        .select(_select)
        .single();
    return TransactionModel.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }
}
