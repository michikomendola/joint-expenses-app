import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/application/auth_providers.dart';
import '../../features/households/application/household_providers.dart';
import '../constants/app_constants.dart';
import '../widgets/state_views.dart';

/// Shown while the user's household membership is being resolved.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: household.hasError && !household.hasValue
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorState(
                        error: household.error,
                        onRetry: () =>
                            ref.read(currentHouseholdProvider.notifier).refresh(),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: scheme.onPrimary,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceLg),
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppConstants.spaceLg),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.6),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
