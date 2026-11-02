import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/money.dart';
import 'package:joint_expenses/features/statement_import/domain/banks/bpi_parser.dart';
import 'package:joint_expenses/features/statement_import/domain/pdf_layout_extractor.dart';
import 'package:joint_expenses/features/statement_import/domain/statement_models.dart';

/// Optional regression against a private local PDF.
/// Copy a BPI SOA to `test_fixtures/bpi_soa_sample.pdf` (git-ignored).
void main() {
  test('parses the private BPI sample when present', () {
    final file = File('test_fixtures/bpi_soa_sample.pdf');
    if (!file.existsSync()) {
      return;
    }
    final bytes = Uint8List.fromList(file.readAsBytesSync());
    final layout = PdfLayoutExtractor.extract(bytes);
    final extraction = BpiParser().parse(
      lines: layout,
      fileFingerprint: sha256.convert(bytes).toString(),
      fileName: 'bpi_soa_sample.pdf',
    );

    expect(extraction.bankName, 'BPI');
    expect(extraction.statementDate, DateTime(2026, 9, 21));
    expect(extraction.cardholders.length, greaterThanOrEqualTo(2));
    expect(extraction.installmentCharges.length, 13);
    expect(extraction.installmentChargeTotal, Money.parse('24865.61'));
    expect(extraction.installmentSummaries.length, 12);
    expect(extraction.remainingInstallmentBalance, Money.parse('240720.63'));
    expect(
      extraction.lines.any((l) => l.detectedType == DetectedLineType.payment),
      isTrue,
    );
    expect(
      extraction.importCandidates.any((l) => l.originalCurrency == 'USD'),
      isTrue,
    );
  });
}
