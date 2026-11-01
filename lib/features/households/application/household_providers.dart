import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/household.dart';
import '../../../data/repositories/household_repository.dart';
import '../../authentication/application/auth_providers.dart';

/// The household the signed-in user belongs to. `null` → onboarding.
final currentHouseholdProvider =
    AsyncNotifierProvider<CurrentHouseholdNotifier, Household?>(
  CurrentHouseholdNotifier.new,
);

class CurrentHouseholdNotifier extends AsyncNotifier<Household?> {
  @override
  Future<Household?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    return ref.read(householdRepositoryProvider).fetchMyHousehold(userId);
  }

  HouseholdRepository get _repo => ref.read(householdRepositoryProvider);

  Future<void> refresh() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncData(null);
      return;
    }
    state = await AsyncValue.guard(() => _repo.fetchMyHousehold(userId));
  }

  /// Creates a household. Throws on failure so the form can show the error.
  Future<void> create(String name, {String currency = AppConstants.defaultCurrency}) async {
    final household = await _repo.createHousehold(name: name, currency: currency);
    state = AsyncData(household);
  }

  Future<void> join(String inviteCode) async {
    final household = await _repo.joinWithInvite(inviteCode);
    state = AsyncData(household);
  }

  Future<void> rename(String name) async {
    final current = state.value;
    if (current == null) return;
    final updated = await _repo.updateHousehold(current.id, name: name);
    state = AsyncData(updated);
  }

  Future<void> changeCurrency(String currency) async {
    final current = state.value;
    if (current == null) return;
    final updated = await _repo.updateHousehold(current.id, currency: currency);
    state = AsyncData(updated);
  }

  /// Applied when a realtime event reports a household change.
  void applyRemote(Household household) {
    if (state.value?.id == household.id) state = AsyncData(household);
  }
}

/// Convenience: the household id or null.
final currentHouseholdIdProvider = Provider<String?>((ref) {
  return ref.watch(currentHouseholdProvider).value?.id;
});

/// Currency code of the active household (defaults to PHP).
final currencyProvider = Provider<String>((ref) {
  return ref.watch(currentHouseholdProvider).value?.currency ??
      AppConstants.defaultCurrency;
});

/// Members of the active household (with profiles).
final householdMembersProvider = FutureProvider<List<HouseholdMember>>((ref) async {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return const [];
  return ref.watch(householdRepositoryProvider).fetchMembers(householdId);
});

/// Quick lookup: user id → display name.
final memberNamesProvider = Provider<Map<String, String>>((ref) {
  final members = ref.watch(householdMembersProvider).value ?? const [];
  return {for (final m in members) m.userId: m.displayName};
});

/// Generates a fresh invite for the active household.
final inviteControllerProvider =
    AsyncNotifierProvider.autoDispose<InviteController, HouseholdInvite?>(
  InviteController.new,
);

class InviteController extends AutoDisposeAsyncNotifier<HouseholdInvite?> {
  @override
  FutureOr<HouseholdInvite?> build() => null;

  Future<void> generate() async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(householdRepositoryProvider).createInvite(householdId),
    );
  }
}
