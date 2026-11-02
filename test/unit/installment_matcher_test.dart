import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/money.dart';
import 'package:joint_expenses/data/models/expense_scope.dart';
import 'package:joint_expenses/features/statement_import/domain/installment_matcher.dart';
import 'package:joint_expenses/features/statement_import/domain/statement_models.dart';

ExtractedLine charge({
  required String merchant,
  required String amount,
  required int number,
  required int total,
}) {
  return ExtractedLine(
    id: '$merchant-$amount',
    sourcePage: 1,
    sourceRow: merchant,
    rawText: merchant,
    detectedType: DetectedLineType.installmentCharge,
    confidence: 0.9,
    transactionDate: DateTime(2026, 10, 21),
    description: merchant,
    amount: Money.parse(amount),
    installmentNumber: number,
    totalInstallments: total,
  );
}

SavedInstallmentPlan plan({
  required String id,
  required String merchant,
  required String amount,
  required int total,
  String scope = 'personal',
  String? assigned,
}) {
  return SavedInstallmentPlan(
    id: id,
    householdId: 'hh',
    normalizedMerchant: normalizeMerchant(merchant),
    monthlyAmount: Money.parse(amount),
    totalInstallments: total,
    expenseScope: scope,
    assignedUserId: assigned,
  );
}

void main() {
  test('reuses a confident plan and ignores installment number', () {
    final match = InstallmentMatcher.match(
      charge: charge(merchant: 'The Loop Ayala', amount: '3490.63', number: 9, total: 24),
      plans: [
        plan(id: 'p1', merchant: 'The Loop Ayala', amount: '3490.63', total: 24, assigned: 'user-2'),
      ],
    );
    expect(match.isConfident, isTrue);
    expect(match.plan!.id, 'p1');
    expect(match.plan!.assignedUserId, 'user-2');
  });

  test('does not merge same merchant with different monthly amounts', () {
    final match = InstallmentMatcher.match(
      charge: charge(merchant: 'The Loop Ayala', amount: '3490.63', number: 8, total: 24),
      plans: [
        plan(id: 'a', merchant: 'The Loop Ayala', amount: '479.17', total: 24),
        plan(id: 'b', merchant: 'The Loop Ayala', amount: '999.17', total: 24),
        plan(id: 'c', merchant: 'The Loop Ayala', amount: '3490.63', total: 24),
      ],
    );
    expect(match.plan!.id, 'c');
  });

  test('ambiguous when two plans still match', () {
    final match = InstallmentMatcher.match(
      charge: charge(merchant: 'The Loop Ayala', amount: '3490.63', number: 8, total: 24),
      plans: [
        plan(id: 'a', merchant: 'The Loop Ayala', amount: '3490.63', total: 24),
        plan(id: 'b', merchant: 'The Loop Ayala', amount: '3490.63', total: 24),
      ],
    );
    expect(match.kind, PlanMatchKind.ambiguous);
  });

  test('joint classification stays joint', () {
    final match = InstallmentMatcher.match(
      charge: charge(merchant: 'Netflix', amount: '625.19', number: 3, total: 12),
      plans: [
        plan(id: 'j', merchant: 'Netflix', amount: '625.19', total: 12, scope: 'joint'),
      ],
    );
    expect(ExpenseScope.fromString(match.plan!.expenseScope), ExpenseScope.joint);
    expect(match.plan!.assignedUserId, isNull);
  });
}
