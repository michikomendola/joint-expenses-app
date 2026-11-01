import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/categories/application/category_providers.dart';
import '../../features/households/application/household_providers.dart';
import '../../features/transactions/application/transaction_providers.dart';
import '../models/household.dart';
import 'supabase_service.dart';

/// Keeps local state in sync with the household's data through Supabase
/// Realtime. Exactly one channel exists per household: the provider is
/// re-created when the household changes and the old channel is removed in
/// `onDispose`, so duplicate subscriptions are impossible.
///
/// Strategy: on any change event we invalidate the affected providers and let
/// them refetch. This is simple, immune to out-of-order events and guarantees
/// both users converge on the same server state (no duplicate rows).
final realtimeSyncProvider = Provider<void>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return;

  final client = ref.watch(supabaseClientProvider);
  final sync = _RealtimeSync(ref, client, householdId)..start();
  ref.onDispose(sync.dispose);
});

class _RealtimeSync {
  _RealtimeSync(this._ref, this._client, this._householdId);

  final Ref _ref;
  final SupabaseClient _client;
  final String _householdId;

  RealtimeChannel? _channel;
  Timer? _debounce;
  final Set<String> _pending = {};

  void start() {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'household_id',
      value: _householdId,
    );

    _channel = _client
        .channel('household:$_householdId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: filter,
          callback: (_) => _schedule('transactions'),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'categories',
          filter: filter,
          callback: (_) => _schedule('categories'),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'household_members',
          filter: filter,
          callback: (_) => _schedule('members'),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'households',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _householdId,
          ),
          callback: _onHouseholdUpdated,
        )
        .subscribe((status, error) {
      if (error != null && kDebugMode) {
        debugPrint('Realtime channel error: $error');
      }
      // After a reconnect we may have missed events → refresh everything.
      // (The very first subscription coincides with the initial fetch.)
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (_subscribedOnce) {
          _schedule('transactions');
          _schedule('categories');
          _schedule('members');
        }
        _subscribedOnce = true;
      }
    });
  }

  bool _subscribedOnce = false;

  void _onHouseholdUpdated(PostgresChangePayload payload) {
    final record = payload.newRecord;
    if (record.isEmpty) return;
    try {
      _ref
          .read(currentHouseholdProvider.notifier)
          .applyRemote(Household.fromJson(record));
    } catch (_) {
      // Ignore malformed payloads – the next full refresh will fix it.
    }
  }

  /// Coalesces bursts of events (e.g. a bulk category reassignment) into a
  /// single refetch per table.
  void _schedule(String table) {
    _pending.add(table);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _flush);
  }

  void _flush() {
    final tables = Set<String>.from(_pending);
    _pending.clear();
    if (tables.contains('transactions')) {
      _ref.invalidate(monthTransactionsProvider);
    }
    if (tables.contains('categories')) {
      _ref.invalidate(categoriesProvider);
      // Category edits change names/colours shown on transactions too.
      _ref.invalidate(monthTransactionsProvider);
    }
    if (tables.contains('members')) {
      _ref.invalidate(householdMembersProvider);
    }
  }

  void dispose() {
    _debounce?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(_client.removeChannel(channel));
    }
  }
}

/// Call when the app returns to the foreground: realtime may have been
/// suspended, so refetch to be safe.
void refreshHouseholdData(WidgetRef ref) {
  ref.invalidate(monthTransactionsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(householdMembersProvider);
}
