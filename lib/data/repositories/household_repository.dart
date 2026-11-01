import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/household.dart';
import '../services/supabase_service.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository(ref.watch(supabaseClientProvider));
});

class HouseholdRepository {
  HouseholdRepository(this._client);

  final SupabaseClient _client;

  /// The household the current user belongs to (first joined wins).
  Future<Household?> fetchMyHousehold(String userId) async {
    final row = await _client
        .from('household_members')
        .select('household:households(*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: true)
        .limit(1)
        .maybeSingle();
    final household = row?['household'];
    if (household is Map<String, dynamic>) return Household.fromJson(household);
    return null;
  }

  Future<Household> createHousehold({
    required String name,
    String currency = 'PHP',
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_household',
      params: {'p_name': name.trim(), 'p_currency': currency},
    );
    return Household.fromJson(row);
  }

  Future<Household> joinWithInvite(String code) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'join_household_with_invite',
      params: {'p_code': code.trim()},
    );
    return Household.fromJson(row);
  }

  Future<HouseholdInvite> createInvite(String householdId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'create_household_invite',
      params: {'p_household_id': householdId},
    );
    if (rows.isEmpty) {
      throw const PostgrestException(message: 'Could not create an invite');
    }
    return HouseholdInvite.fromJson(rows.first as Map<String, dynamic>);
  }

  Future<List<HouseholdMember>> fetchMembers(String householdId) async {
    final rows = await _client
        .from('household_members')
        .select('*, profile:profiles(*)')
        .eq('household_id', householdId)
        .order('joined_at', ascending: true);
    return rows.map(HouseholdMember.fromJson).toList(growable: false);
  }

  Future<Household> updateHousehold(
    String householdId, {
    String? name,
    String? currency,
  }) async {
    final patch = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (currency != null) 'currency': currency.toUpperCase(),
    };
    final row = await _client
        .from('households')
        .update(patch)
        .eq('id', householdId)
        .select()
        .single();
    return Household.fromJson(row);
  }
}
