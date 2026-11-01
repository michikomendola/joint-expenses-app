import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/application/settings_providers.dart';
import 'setup_screen.dart';

class JointExpensesApp extends ConsumerWidget {
  const JointExpensesApp({super.key, this.configured = true});

  /// False when Supabase credentials were not provided at build time.
  final bool configured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    if (!configured) {
      return MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const SetupScreen(),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Respect user font scaling but keep layouts from breaking at the
        // largest accessibility sizes.
        final media = MediaQuery.of(context);
        final clamped = media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.4);
        return MediaQuery(
          data: media.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
