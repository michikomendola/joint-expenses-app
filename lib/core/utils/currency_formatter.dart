import 'package:intl/intl.dart';

import 'money.dart';

/// A currency the household can be configured with.
class AppCurrency {
  const AppCurrency(this.code, this.symbol, this.name);

  final String code;
  final String symbol;
  final String name;
}

/// Formats [Money] values with thousands separators and two decimals.
///
/// Formatting is performed on the integer parts of the value so no
/// floating-point conversion is involved.
abstract final class CurrencyFormatter {
  static const List<AppCurrency> supported = [
    AppCurrency('PHP', '₱', 'Philippine Peso'),
    AppCurrency('USD', '\$', 'US Dollar'),
    AppCurrency('EUR', '€', 'Euro'),
    AppCurrency('GBP', '£', 'British Pound'),
    AppCurrency('JPY', '¥', 'Japanese Yen'),
    AppCurrency('SGD', 'S\$', 'Singapore Dollar'),
    AppCurrency('AUD', 'A\$', 'Australian Dollar'),
    AppCurrency('CAD', 'C\$', 'Canadian Dollar'),
    AppCurrency('HKD', 'HK\$', 'Hong Kong Dollar'),
    AppCurrency('INR', '₹', 'Indian Rupee'),
    AppCurrency('KRW', '₩', 'South Korean Won'),
    AppCurrency('MYR', 'RM', 'Malaysian Ringgit'),
    AppCurrency('IDR', 'Rp', 'Indonesian Rupiah'),
    AppCurrency('THB', '฿', 'Thai Baht'),
    AppCurrency('AED', 'AED ', 'UAE Dirham'),
    AppCurrency('NZD', 'NZ\$', 'New Zealand Dollar'),
  ];

  static final NumberFormat _grouping = NumberFormat('#,##0', 'en_US');

  static AppCurrency currency(String code) {
    final upper = code.toUpperCase();
    return supported.firstWhere(
      (c) => c.code == upper,
      orElse: () => AppCurrency(upper, '$upper ', upper),
    );
  }

  static String symbol(String code) => currency(code).symbol;

  /// `₱50,000.00`, `-₱1,200.00`.
  static String format(Money money, {String currency = 'PHP'}) {
    final sign = money.isNegative ? '-' : '';
    return '$sign${symbol(currency)}${_digits(money)}';
  }

  /// `+ ₱30,000.00` / `- ₱1,200.00` for transaction lists.
  /// A negative expense is a refund, so it is shown as money coming back.
  static String formatSigned(
    Money money, {
    required String currency,
    required bool isIncome,
  }) {
    final credit = isIncome ? !money.isNegative : money.isNegative;
    final prefix = credit ? '+ ' : '- ';
    return '$prefix${symbol(currency)}${_digits(money.abs)}';
  }

  /// `50,000.00` without symbol – used in input fields and chart labels.
  static String digits(Money money) {
    final sign = money.isNegative ? '-' : '';
    return '$sign${_digits(money)}';
  }

  static String _digits(Money money) {
    final whole = _grouping.format(money.wholeUnits);
    final cents = money.fractionUnits.toString().padLeft(2, '0');
    return '$whole.$cents';
  }

  /// `1.2K`, `45.0K`, `1.5M` – used for compact chart badges.
  static String compact(Money money, {String currency = 'PHP'}) {
    final abs = money.abs;
    final units = abs.minor / 100;
    final sign = money.isNegative ? '-' : '';
    final sym = symbol(currency);
    if (units >= 1000000) {
      return '$sign$sym${(units / 1000000).toStringAsFixed(1)}M';
    }
    if (units >= 1000) {
      return '$sign$sym${(units / 1000).toStringAsFixed(1)}K';
    }
    return '$sign$sym${_digits(abs)}';
  }
}
