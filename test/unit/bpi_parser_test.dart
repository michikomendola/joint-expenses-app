import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/money.dart';
import 'package:joint_expenses/features/statement_import/domain/banks/bpi_parser.dart';
import 'package:joint_expenses/features/statement_import/domain/pdf_tokens.dart';
import 'package:joint_expenses/features/statement_import/domain/statement_models.dart';

import '../helpers/pdf_lines.dart';

void main() {
  final parser = BpiParser();

  StatementExtraction parse([List<PdfLayoutLine>? lines]) {
    return parser.parse(
      lines: lines ?? bpiSampleLayout(),
      fileFingerprint: 'test-fingerprint',
      fileName: 'sample.pdf',
    );
  }

  test('recognises BPI layout', () {
    expect(parser.matches(bpiSampleLayout()), isTrue);
  });

  test('TEST 1: uses transaction date, not post date', () {
    final extraction = parse();
    final shopee = extraction.importCandidates.firstWhere(
      (l) => (l.description ?? '').toLowerCase().contains('shopee') &&
          l.amount == Money.parse('1016.00'),
    );
    expect(shopee.transactionDate, DateTime(2026, 8, 24));
    expect(shopee.postDate, DateTime(2026, 8, 26));
  });

  test('TEST 2: installment 08/24 is not a calendar date', () {
    final extraction = parse();
    final loop = extraction.installmentCharges.firstWhere(
      (l) => l.amount == Money.parse('3490.63'),
    );
    expect(loop.detectedType, DetectedLineType.installmentCharge);
    expect(loop.installmentNumber, 8);
    expect(loop.totalInstallments, 24);
    expect(loop.amount, Money.parse('3490.63'));
    expect(loop.transactionDate, DateTime(2026, 9, 21));
  });

  test('TEST 3: same merchant, three distinct plans', () {
    final extraction = parse();
    final loops = extraction.installmentCharges
        .where((l) => (l.description ?? '').toLowerCase().contains('the loop'))
        .toList();
    expect(loops.length, 3);
    final amounts = loops.map((l) => l.amount!.toDecimalString()).toSet();
    expect(amounts, {'479.17', '999.17', '3490.63'});
  });

  test('TEST 4: 13 installment charges and summary remaining balance', () {
    final extraction = parse();
    expect(extraction.installmentCharges.length, 13);
    expect(extraction.installmentChargeTotal, Money.parse('24865.61'));
    expect(extraction.installmentSummaries.length, 12);
    expect(extraction.remainingInstallmentBalance, Money.parse('240720.63'));
    // Remaining balance is tracking only — not an import candidate.
    expect(
      extraction.importCandidates.any((l) => l.amount == Money.parse('240720.63')),
      isFalse,
    );
    final completed = extraction.installmentCharges.singleWhere(
      (l) => l.installmentNumber == 6 && l.totalInstallments == 6,
    );
    expect(completed.description!.toLowerCase(), contains('ace hardware'));
  });

  test('TEST 5: payment is not a purchase', () {
    final extraction = parse();
    final payment = extraction.lines.firstWhere(
      (l) => l.detectedType == DetectedLineType.payment,
    );
    expect(payment.description!.toLowerCase(), contains('thank you'));
    expect(extraction.importCandidates.contains(payment), isFalse);
  });

  test('TEST 6: foreign currency uses billed PHP only', () {
    final extraction = parse();
    final cursor = extraction.importCandidates.where(
      (l) => (l.description ?? '').toLowerCase().contains('cursor'),
    );
    expect(cursor.length, 1);
    expect(cursor.single.amount, Money.parse('1276.65'));
    expect(cursor.single.originalCurrency, 'USD');
    expect(cursor.single.originalAmount, Money.parse('20.00'));
  });

  test('TEST 11: cardholder sections stay separate', () {
    final extraction = parse();
    expect(extraction.cardholders.length, 2);
    expect(extraction.cardholders.first.kind, CardKind.principal);
    expect(extraction.cardholders.last.kind, CardKind.supplementary);
    final principalHash = extraction.cardholders.first.identifierHash;
    final shopee = extraction.importCandidates.firstWhere(
      (l) => l.amount == Money.parse('1016.00'),
    );
    final loop = extraction.installmentCharges.firstWhere(
      (l) => l.amount == Money.parse('3490.63'),
    );
    expect(shopee.cardholderHash, principalHash);
    expect(loop.cardholderHash, isNot(principalHash));
  });

  test('TEST 12: balances and instructions are not purchases', () {
    final extraction = parse();
    expect(
      extraction.importCandidates.any(
        (l) => (l.description ?? '').toLowerCase().contains('previous balance'),
      ),
      isFalse,
    );
    expect(
      extraction.lines.any((l) => (l.rawText.toLowerCase()).contains('please use your customer')),
      isFalse,
    );
  });

  test('Installment Purchase rows are not imported as purchases', () {
    final extraction = parse();
    final original = extraction.lines.singleWhere(
      (l) => l.amount == Money.parse('15000.00'),
    );
    expect(original.detectedType, DetectedLineType.installmentPurchase);
    expect(extraction.importCandidates.contains(original), isFalse);
    expect(
      extraction.importCandidates.any((l) => l.amount == Money.parse('15000.00')),
      isFalse,
    );
    expect(
      extraction.importCandidates.any(
        (l) => (l.description ?? '').toLowerCase().contains('shopee') &&
            l.amount == Money.parse('1016.00'),
      ),
      isTrue,
    );
  });

  test('refunds stay negative and can be imported', () {
    final extraction = parse();
    final refunds = extraction.lines.where((l) => l.detectedType == DetectedLineType.refund);
    expect(refunds, isNotEmpty);
    expect(refunds.every((l) => l.amount != null && l.amount!.isNegative), isTrue);
    expect(extraction.importCandidates.where((l) => refunds.contains(l)), isNotEmpty);
  });
}
