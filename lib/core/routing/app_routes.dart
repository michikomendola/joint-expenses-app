/// Route paths used by GoRouter and navigation calls.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String setup = '/setup';

  static const String login = '/auth/login';
  static const String signUp = '/auth/sign-up';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  static const String onboarding = '/onboarding';

  static const String home = '/';
  static const String transactions = '/transactions';
  static const String statementImport = '/transactions/import-statement';
  static const String statementReview = '/transactions/import-statement/review';
  static const String categories = '/categories';
  static const String settings = '/settings';
}
