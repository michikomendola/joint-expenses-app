/// App-wide constants: animation durations, limits and spacing.
abstract final class AppConstants {
  static const String appName = 'Joint Expenses';
  static const String defaultCurrency = 'PHP';

  // Animation timing (spec: 180–300 ms).
  static const Duration animFast = Duration(milliseconds: 180);
  static const Duration animMedium = Duration(milliseconds: 240);
  static const Duration animSlow = Duration(milliseconds: 300);
  static const Duration numberAnimation = Duration(milliseconds: 450);

  // Limits mirrored from the database constraints.
  static const int maxDescriptionLength = 200;
  static const int maxCategoryNameLength = 40;
  static const int maxHouseholdNameLength = 60;
  static const int maxDisplayNameLength = 50;
  static const int minPasswordLength = 8;

  /// Largest amount accepted by the form (numeric(14,2) in the database).
  static const int maxAmountMinor = 99999999999999; // 999,999,999,999.99

  static const int recentTransactionsCount = 5;
  static const int inviteCodeLength = 10;

  // Spacing scale.
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
}
