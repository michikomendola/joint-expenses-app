import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_env.dart';
import '../data/services/supabase_service.dart';

/// Initialises platform services and returns the provider overrides the app
/// needs. Returns `null` for [BootstrapResult.overrides] when Supabase is not
/// configured so the UI can show setup instructions instead of crashing.
class BootstrapResult {
  const BootstrapResult({required this.overrides, required this.configured});

  final List<Override> overrides;
  final bool configured;
}

Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  final overrides = <Override>[
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];

  if (!AppEnv.isConfigured) {
    return BootstrapResult(overrides: overrides, configured: false);
  }

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    // Accepts both the legacy `anon` JWT and the new `sb_publishable_…` key.
    publishableKey: AppEnv.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10,
    ),
  );

  return BootstrapResult(overrides: overrides, configured: true);
}
