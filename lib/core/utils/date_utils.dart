import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// A calendar month, used by the dashboard month filter.
@immutable
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month)
      : assert(month >= 1 && month <= 12, 'month must be 1..12');

  factory YearMonth.fromDate(DateTime date) => YearMonth(date.year, date.month);

  factory YearMonth.now() => YearMonth.fromDate(DateTime.now());

  final int year;
  final int month;

  /// First day of the month (local, midnight).
  DateTime get start => DateTime(year, month);

  /// First day of the next month (exclusive upper bound).
  DateTime get endExclusive => DateTime(year, month + 1);

  /// Last day of the month.
  DateTime get end => DateTime(year, month + 1, 0);

  YearMonth get previous =>
      month == 1 ? YearMonth(year - 1, 12) : YearMonth(year, month - 1);

  YearMonth get next =>
      month == 12 ? YearMonth(year + 1, 1) : YearMonth(year, month + 1);

  bool get isCurrent {
    final now = DateTime.now();
    return now.year == year && now.month == month;
  }

  bool contains(DateTime date) => date.year == year && date.month == month;

  /// `November 2026`
  String get label => DateFormat.yMMMM().format(start);

  /// `Nov 2026`
  String get shortLabel => DateFormat.yMMM().format(start);

  /// `2026-11-01` – inclusive lower bound for SQL.
  String get startIso => AppDateUtils.toIsoDate(start);

  /// `2026-11-30` – inclusive upper bound for SQL.
  String get endIso => AppDateUtils.toIsoDate(end);

  @override
  int compareTo(YearMonth other) =>
      year != other.year ? year.compareTo(other.year) : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'YearMonth($year-$month)';
}

abstract final class AppDateUtils {
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime today() => dateOnly(DateTime.now());

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// `2026-11-01`
  static String toIsoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// Parses a `date` column (`yyyy-MM-dd`) as a local midnight DateTime.
  static DateTime parseIsoDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Header label for grouped lists: Today / Yesterday / `Monday, 3 Nov` /
  /// `3 Nov 2025` for other years.
  static String groupLabel(DateTime date, {DateTime? now}) {
    final reference = dateOnly(now ?? DateTime.now());
    final day = dateOnly(date);
    final difference = reference.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference == -1) return 'Tomorrow';
    if (day.year == reference.year) {
      return DateFormat('EEEE, d MMM').format(day);
    }
    return DateFormat('d MMM yyyy').format(day);
  }

  /// `3 Nov 2026`
  static String shortDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

  /// `Tue, 3 Nov 2026`
  static String mediumDate(DateTime date) =>
      DateFormat('EEE, d MMM yyyy').format(date);

  /// Compact list label: `Today`, `Yesterday`, `3 Nov`.
  static String relativeShort(DateTime date, {DateTime? now}) {
    final reference = dateOnly(now ?? DateTime.now());
    final day = dateOnly(date);
    final difference = reference.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (day.year == reference.year) return DateFormat('d MMM').format(day);
    return DateFormat('d MMM yyyy').format(day);
  }

  static String greeting({DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}
