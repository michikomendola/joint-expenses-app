import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/amount_input_formatter.dart';
import 'package:joint_expenses/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b.co'), isNull);
    });

    test('password requires 8 characters', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('longenough'), isNull);
      expect(Validators.confirmPassword('abc', 'abd'), isNotNull);
      expect(Validators.confirmPassword('abc', 'abc'), isNull);
    });

    test('amount must be a non-zero decimal', () {
      expect(Validators.amount(''), 'Amount is required');
      expect(Validators.amount('0'), 'Amount must not be zero');
      expect(Validators.amount('-12.30'), 'Amount must be greater than zero');
      expect(Validators.amount('-12.30', allowNegative: true), isNull);
      expect(Validators.amount('abc'), 'Enter a valid amount');
      expect(Validators.amount('1.234'), 'Enter a valid amount');
      expect(Validators.amount('1500.50'), isNull);
      expect(Validators.amount('9999999999999'), 'Amount is too large');
      expect(Validators.amount('-9999999999999', allowNegative: true), 'Amount is too large');
    });

    test('invite code must be 10 alphanumerics ignoring dashes', () {
      expect(Validators.inviteCode('ABCDE-FGHJK'), isNull);
      expect(Validators.inviteCode('abcdefghjk'), isNull);
      expect(Validators.inviteCode('ABC'), isNotNull);
      expect(Validators.inviteCode(''), isNotNull);
    });

    test('names respect length limits', () {
      expect(Validators.householdName(''), isNotNull);
      expect(Validators.householdName('A' * 61), isNotNull);
      expect(Validators.householdName('Our Finances'), isNull);
      expect(Validators.categoryName('A' * 41), isNotNull);
      expect(Validators.description('x' * 201), isNotNull);
      expect(Validators.description(null), isNull);
    });
  });

  group('AmountInputFormatter', () {
    const formatter = AmountInputFormatter();

    TextEditingValue apply(String old, String next) => formatter.formatEditUpdate(
          TextEditingValue(text: old),
          TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length)),
        );

    test('allows digits and a single decimal point', () {
      expect(apply('12', '12.').text, '12.');
      expect(apply('12.', '12.5').text, '12.5');
      expect(apply('12.5', '12.50').text, '12.50');
    });

    test('rejects a third decimal digit and letters', () {
      expect(apply('12.50', '12.505').text, '12.50');
      expect(apply('12', '12a').text, '12');
    });

    test('normalises comma to dot and collapses duplicate separators', () {
      expect(apply('12', '12,5').text, '12.5');
      expect(apply('1.', '1..').text, '1.');
    });

    test('strips leading zeros but keeps 0.x', () {
      expect(apply('0', '07').text, '7');
      expect(apply('0', '0.').text, '0.');
      expect(apply('0.', '0.5').text, '0.5');
    });

    test('limits integer digits', () {
      expect(apply('123456789012', '1234567890123').text, '123456789012');
    });

    test('keeps a leading minus only when negatives are allowed', () {
      const signed = AmountInputFormatter(allowNegative: true);
      TextEditingValue applySigned(String old, String next) => signed.formatEditUpdate(
            TextEditingValue(text: old),
            TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length)),
          );

      expect(apply('12', '-12').text, '12');
      expect(applySigned('', '-').text, '-');
      expect(applySigned('-', '-12.5').text, '-12.5');
      expect(applySigned('-12.5', '-12.50').text, '-12.50');
      expect(applySigned('-', '-007').text, '-7');
    });
  });
}
