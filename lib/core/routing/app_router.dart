import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/application/auth_providers.dart';
import '../../features/authentication/presentation/forgot_password_screen.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/reset_password_screen.dart';
import '../../features/authentication/presentation/sign_up_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/households/application/household_providers.dart';
import '../../features/households/presentation/household_setup_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/statement_import/presentation/statement_review_screen.dart';
import '../../features/statement_import/presentation/statement_upload_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../constants/app_constants.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Bridges Riverpod state into GoRouter's `refreshListenable`.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(currentUserIdProvider, (_, _) => notifyListeners());
    _ref.listen(currentHouseholdProvider, (_, _) => notifyListeners());
    _ref.listen(passwordRecoveryProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    final userId = _ref.read(currentUserIdProvider);
    final recovering = _ref.read(passwordRecoveryProvider);
    final isAuthRoute = location.startsWith('/auth');

    if (userId == null) {
      return isAuthRoute && location != AppRoutes.resetPassword
          ? null
          : AppRoutes.login;
    }

    if (recovering) {
      return location == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
    }

    final household = _ref.read(currentHouseholdProvider);
    if (household.isLoading && !household.hasValue) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }
    if (household.hasError && !household.hasValue) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final hasHousehold = household.value != null;
    if (!hasHousehold) {
      return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
    }

    if (isAuthRoute ||
        location == AppRoutes.splash ||
        location == AppRoutes.onboarding) {
      return AppRoutes.home;
    }
    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        pageBuilder: (context, state) => _slidePage(state, const SignUpScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) =>
            _slidePage(state, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        pageBuilder: (context, state) =>
            _fadePage(state, const ResetPasswordScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) =>
            _fadePage(state, const HouseholdSetupScreen()),
      ),
      GoRoute(
        path: AppRoutes.statementImport,
        pageBuilder: (context, state) =>
            _slidePage(state, const StatementUploadScreen()),
        routes: [
          GoRoute(
            path: 'review',
            pageBuilder: (context, state) =>
                _slidePage(state, const StatementReviewScreen()),
          ),
        ],
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) => navigationShell,
        navigatorContainerBuilder: (context, navigationShell, children) =>
            AppShell(navigationShell: navigationShell, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: TransactionsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.categories,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CategoriesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppConstants.animMedium,
    reverseTransitionDuration: AppConstants.animFast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppConstants.animSlow,
    reverseTransitionDuration: AppConstants.animMedium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
