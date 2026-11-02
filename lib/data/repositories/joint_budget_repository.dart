import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/joint_budget_share.dart';
import '../services/supabase_service.dart';

final jointBudgetRepositoryProvider = Provider<JointBudgetRepository>((ref) {
  return JointBudgetRepository(ref.watch(supabaseClientProvider));
});

class JointBudgetRepository {
  JointBudgetRepository(this._client);

  final SupabaseClient _client;

  Future<List<JointBudgetShare>> fetchShares(String householdId) async {
    final rows = await _client
        .from('joint_budget_settlements')
        .select()
        .eq('household_id', householdId)
        .order('shared_at', ascending: false);
    return rows.map(JointBudgetShare.fromJson).toList(growable: false);
  }

  Future<JointBudgetShare> shareDeficit(String householdId) async {
    final result = await _client.rpc(
      'share_joint_deficit',
      params: {'p_household_id': householdId},
    );
    final row = result is List
        ? Map<String, dynamic>.from(result.first as Map)
        : Map<String, dynamic>.from(result as Map);
    return JointBudgetShare.fromJson(row);
  }

  Future<void> undoShare(String id) async {
    await _client.rpc<void>(
      'undo_joint_deficit_share',
      params: {'p_id': id},
    );
  }
}
