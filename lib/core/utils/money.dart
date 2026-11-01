import 'package:flutter/foundation.dart';

/// Exact monetary value stored as integer minor units (centavos / cents).
///
/// All arithmetic is performed on integers so there are no floating-point
/// rounding errors. Conversion to `double` only happens for display purposes
/// (animations) and never feeds back into calculations.
@immutable
class Money implements Comparable<Money> {
  const Money.fromMinor(this.minor);

  /// Builds a value from whole units and a 0–99 fraction.
  const Money.fromUnits(int units, [int cents = 0]) : minor = units * 100 + cents;

  static const Money zero = Money.fromMinor(0);

  /// Minor units (e.g. centavos). Can be negative for balances.
  final int minor;

  /// Parses the JSON representation returned by PostgREST for `numeric`
  /// columns. PostgREST may emit a number or a string depending on settings.
  factory Money.fromJson(Object? value) {
    if (value == null) return zero;
    if (value is int) return Money.fromMinor(value * 100);
    if (value is double) return Money.fromMinor((value * 100).round());
    if (value is String) {
      final parsed = Money.tryParse(value);
      if (parsed == null) {
        throw FormatException('Invalid monetary value', value);
      }
      return parsed;
    }
    throw FormatException('Unsupported monetary value type', value);
  }

  /// Parses a decimal string such as `1500`, `1,500.50`, `-12.3`.
  /// Returns `null` for invalid input or more than two decimal places.
  static Money? tryParse(String input) {
    var text = input.trim().replaceAll(',', '').replaceAll(' ', '');
    if (text.isEmpty) return null;

    var negative = false;
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    } else if (text.startsWith('+')) {
      text = text.substring(1);
    }
    if (text.isEmpty) return null;

    final match = RegExp(r'^(\d*)(?:\.(\d{0,2}))?$').firstMatch(text);
    if (match == null) return null;

    final wholeText = match.group(1) ?? '';
    final fractionText = (match.group(2) ?? '').padRight(2, '0');
    if (wholeText.isEmpty && (match.group(2) ?? '').isEmpty) return null;

    final whole = wholeText.isEmpty ? 0 : int.tryParse(wholeText);
    final fraction = int.tryParse(fractionText);
    if (whole == null || fraction == null) return null;

    final minor = whole * 100 + fraction;
    return Money.fromMinor(negative ? -minor : minor);
  }

  static Money parse(String input) {
    final result = tryParse(input);
    if (result == null) throw FormatException('Invalid monetary value', input);
    return result;
  }

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money get abs => Money.fromMinor(minor.abs());

  int get wholeUnits => minor.abs() ~/ 100;
  int get fractionUnits => minor.abs() % 100;

  Money operator +(Money other) => Money.fromMinor(minor + other.minor);
  Money operator -(Money other) => Money.fromMinor(minor - other.minor);
  Money operator -() => Money.fromMinor(-minor);
  bool operator <(Money other) => minor < other.minor;
  bool operator >(Money other) => minor > other.minor;
  bool operator <=(Money other) => minor <= other.minor;
  bool operator >=(Money other) => minor >= other.minor;

  /// Fraction of [total] this value represents, in the range 0..1.
  /// Division by zero is handled by returning 0.
  double ratioOf(Money total) {
    if (total.minor == 0) return 0;
    return minor / total.minor;
  }

  /// Percentage of [total] (0..100), safe when [total] is zero.
  double percentOf(Money total) => ratioOf(total) * 100;

  /// Plain decimal string with exactly two fraction digits, e.g. `1500.00`.
  /// This is what is sent to the database.
  String toDecimalString() {
    final sign = isNegative ? '-' : '';
    return '$sign$wholeUnits.${fractionUnits.toString().padLeft(2, '0')}';
  }

  String toJson() => toDecimalString();

  /// For animations and chart geometry only – never for calculations.
  double toDouble() => minor / 100;

  static Money sum(Iterable<Money> values) =>
      values.fold(zero, (acc, value) => acc + value);

  @override
  int compareTo(Money other) => minor.compareTo(other.minor);

  @override
  bool operator ==(Object other) => other is Money && other.minor == minor;

  @override
  int get hashCode => minor.hashCode;

  @override
  String toString() => 'Money(${toDecimalString()})';
}
