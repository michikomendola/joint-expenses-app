import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/profile.dart';
import '../../../data/repositories/auth_repository.dart';

/// Emits every auth event (sign-in, sign-out, token refresh, recovery...).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// The signed-in user, or null. Re-evaluated on every auth event.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});

/// True while the app is handling a password-recovery deep link.
final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, bool>(PasswordRecoveryNotifier.new);

class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authStateChangesProvider, (previous, next) {
      final event = next.value?.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        state = true;
      } else if (event == AuthChangeEvent.signedOut) {
        state = false;
      }
    });
    return false;
  }

  void complete() => state = false;
}

/// The current user's profile row.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repository = ref.watch(authRepositoryProvider);
  final profile = await repository.fetchProfile(user.id);
  // Fallback (profile trigger not yet applied): derive from auth metadata.
  return profile ??
      Profile(
        id: user.id,
        displayName: (user.userMetadata?['display_name'] as String?)?.trim() ??
            user.email?.split('@').first ??
            'Member',
        email: user.email,
      );
});

/// Mutations for the auth feature. State is `AsyncValue<void>` so screens
/// can show loading and error feedback.
final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(AuthController.new);

class AuthController extends AutoDisposeAsyncNotifier<void> {
  // Synchronous build → the initial state is `AsyncData`, not loading.
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.signIn(email: email, password: password),
    );
    return !state.hasError;
  }

  /// Returns `true` when a session was created immediately, `false` when the
  /// user must confirm their e-mail first, or `null` on error.
  Future<bool?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    bool? result;
    state = await AsyncValue.guard(() async {
      final response = await _repo.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      result = response.session != null;
    });
    return state.hasError ? null : result;
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.sendPasswordReset(email));
    return !state.hasError;
  }

  Future<bool> updatePassword(String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.updatePassword(password));
    if (!state.hasError) ref.read(passwordRecoveryProvider.notifier).complete();
    return !state.hasError;
  }

  Future<bool> updateDisplayName(String displayName) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.updateDisplayName(user.id, displayName),
    );
    if (!state.hasError) ref.invalidate(currentProfileProvider);
    return !state.hasError;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.signOut);
  }

  Future<bool> deleteAccount() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.deleteAccount);
    return !state.hasError;
  }
}
