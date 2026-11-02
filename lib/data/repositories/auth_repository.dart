import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_env.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Wraps Supabase Auth and the `profiles` table.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Returns the response; `session` is null when e-mail confirmation is on.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
      emailRedirectTo: AppEnv.loginCallbackRedirect,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppEnv.passwordResetRedirect,
    );
  }

  Future<void> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Deletes the signed-in auth user and the personal data attached to them.
  /// The database function keeps a shared household for any remaining member.
  Future<void> deleteAccount() async {
    await _client.rpc('delete_own_account');
    try {
      await _client.auth.signOut();
    } catch (_) {
      await _client.auth.signOut(scope: SignOutScope.local);
    }
  }

  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<Profile> updateDisplayName(String userId, String displayName) async {
    final trimmed = displayName.trim();
    final row = await _client
        .from('profiles')
        .update({'display_name': trimmed})
        .eq('id', userId)
        .select()
        .single();
    // Keep auth metadata aligned so future profile rebuilds use the new name.
    await _client.auth.updateUser(UserAttributes(data: {'display_name': trimmed}));
    return Profile.fromJson(row);
  }
}
