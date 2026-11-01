import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/supabase_service.dart';

const _themeModeKey = 'theme_mode';

/// Persisted theme preference. Light by default.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.light,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_themeModeKey, mode.name);
  }
}
