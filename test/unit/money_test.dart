import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/currency_formatter.dart';
import 'package:joint_expenses/core/utils/money.dart';

void main() {
  group('Money.tryParse', () {
    test('parses whole numbers', () {
      expect(Money.tryParse('45000'), const Money.fromMinor(4500000));
    });

    test('parses decimals and pads to two places', () {
      expect(Money.tryParse('1500.5'), const Money.fromMinor(150050));
      expect(Money.tryParse('0.07'), const Money.fromMinor(7));
      expect(Money.tryParse('.5'), const Money.fromMinor(50));
    });

    test('accepts thousands separators and whitespace', () {
      expect(Money.tryParse(' 1,234,567.89 '), const Money.fromMinor(123456789));
    });

    test('rejects invalid input', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('1.234'), isNull, reason: 'more than 2 decimals');
      expect(Money.tryParse('1..2'), isNull);
      expect(Money.tryParse('-'), isNull);
    });

    test('parses negative values', () {
      expect(Money.tryParse('-12.30'), const Money.fromMinor(-1230));
    });
  });

  group('Money.fromJson', () {
    test('handles int, double and string from PostgREST', () {
      expect(Money.fromJson(1500), const Money.fromMinor(150000));
      expect(Money.fromJson(1500.75), const Money.fromMinor(150075));
      expect(Money.fromJson('1500.75'), const Money.fromMinor(150075));
      expect(Money.fromJson(null), Money.zero);
    });

    test('avoids floating point drift for typical values', () {
      // 0.1 + 0.2 style issue must not leak into the integer representation.
      expect(Money.fromJson(0.1) + Money.fromJson(0.2), const Money.fromMinor(30));
      expect(Money.fromJson(1234.56), const Money.fromMinor(123456));
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts exactly', () {
      final a = Money.parse('45000');
      final b = Money.parse('30000');
      expect(a + b, Money.parse('75000'));
      expect(a - b, Money.parse('15000'));
      expect(b - a, Money.parse('-15000'));
    });

    test('sum of many small values has no rounding error', () {
      final values = List.generate(1000, (_) => Money.parse('0.10'));
      expect(Money.sum(values), Money.parse('100.00'));
    });

    test('ratio and percentage handle zero totals safely', () {
      expect(Money.parse('50').ratioOf(Money.zero), 0);
      expect(Money.parse('50').percentOf(Money.zero), 0);
      expect(Money.parse('25').percentOf(Money.parse('100')), 25);
      expect(Money.parse('1').percentOf(Money.parse('3')), closeTo(33.33, 0.01));
    });

    test('toDecimalString always has two fraction digits', () {
      expect(Money.parse('5').toDecimalString(), '5.00');
      expect(Money.parse('5.5').toDecimalString(), '5.50');
      expect(const Money.fromMinor(-105).toDecimalString(), '-1.05');
      expect(Money.zero.toDecimalString(), '0.00');
    });

    test('comparison operators', () {
      expect(Money.parse('1') < Money.parse('2'), isTrue);
      expect(Money.parse('2') >= Money.parse('2'), isTrue);
      expect([Money.parse('3'), Money.parse('1'), Money.parse('2')]..sort(),
          [Money.parse('1'), Money.parse('2'), Money.parse('3')]);
    });
  });

  group('CurrencyFormatter', () {
    test('formats PHP with thousands separators and two decimals', () {
      expect(CurrencyFormatter.format(Money.parse('50000')), '₱50,000.00');
      expect(CurrencyFormatter.format(Money.parse('1234567.8')), '₱1,234,567.80');
      expect(CurrencyFormatter.format(Money.parse('0')), '₱0.00');
    });

    test('formats negative balances', () {
      expect(CurrencyFormatter.format(Money.parse('-1200')), '-₱1,200.00');
    });

    test('formats other currencies', () {
      expect(CurrencyFormatter.format(Money.parse('99.9'), currency: 'USD'), '\$99.90');
      expect(CurrencyFormatter.format(Money.parse('10'), currency: 'EUR'), '€10.00');
      expect(CurrencyFormatter.format(Money.parse('10'), currency: 'XYZ'), 'XYZ 10.00');
    });

    test('signed format for lists', () {
      expect(
        CurrencyFormatter.formatSigned(Money.parse('30000'), currency: 'PHP', isIncome: true),
        '+ ₱30,000.00',
      );
      expect(
        CurrencyFormatter.formatSigned(Money.parse('1200'), currency: 'PHP', isIncome: false),
        '- ₱1,200.00',
      );
      expect(
        CurrencyFormatter.formatSigned(Money.parse('-80'), currency: 'PHP', isIncome: false),
        '+ ₱80.00',
      );
    });

    test('compact format', () {
      expect(CurrencyFormatter.compact(Money.parse('950')), '₱950.00');
      expect(CurrencyFormatter.compact(Money.parse('45000')), '₱45.0K');
      expect(CurrencyFormatter.compact(Money.parse('1500000')), '₱1.5M');
      expect(CurrencyFormatter.compact(Money.parse('-2500')), '-₱2.5K');
    });
  });
}
