import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/data/models/expense_scope.dart';
import 'package:joint_expenses/data/models/payment_method.dart';
import 'package:joint_expenses/data/models/transaction.dart';
import 'package:joint_expenses/data/models/transaction_type.dart';
import 'package:joint_expenses/core/utils/money.dart';

void main() {
  test('parses stored payment methods', () {
    expect(PaymentMethod.fromString('cc'), PaymentMethod.cc);
    expect(PaymentMethod.fromString('gcash'), PaymentMethod.gcash);
    expect(PaymentMethod.fromString(null), PaymentMethod.cash);
    expect(PaymentMethod.cc.label, 'CC');
    expect(PaymentMethod.seabank.label, 'SeaBank');
  });

  test('manual expense payload includes the chosen mop', () {
    final input = TransactionInput(
      type: TransactionType.expense,
      amount: Money.parse('100'),
      categoryId: 'cat',
      transactionDate: DateTime(2026, 11, 1),
      paymentMethod: PaymentMethod.maya,
    );
    expect(input.toJson()['payment_method'], 'maya');
  });

  test('joint manual expense clears assigned user', () {
    final input = TransactionInput(
      type: TransactionType.expense,
      amount: Money.parse('10000'),
      categoryId: 'cat',
      transactionDate: DateTime(2026, 11, 1),
      expenseScope: ExpenseScope.joint,
    );
    final json = input.toJson(userId: 'user-1');
    expect(json['expense_scope'], 'joint');
    expect(json['assigned_user_id'], isNull);
  });

  test('joint income payload feeds the joint pot', () {
    final input = TransactionInput(
      type: TransactionType.income,
      amount: Money.parse('15000'),
      categoryId: 'cat',
      transactionDate: DateTime(2026, 11, 1),
      expenseScope: ExpenseScope.joint,
    );
    final json = input.toJson(userId: 'user-1');
    expect(json['expense_scope'], 'joint');
    expect(json['assigned_user_id'], isNull);
  });
}
