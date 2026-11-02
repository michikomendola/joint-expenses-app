import '../pdf_tokens.dart';
import '../statement_models.dart';

/// Contract for a bank-specific statement parser.
///
/// Add a new implementation and register it in [BankParserRegistry] — do not
/// extend the BPI class with another bank's quirks.
abstract class BankParser {
  String get bankId;
  String get displayName;

  /// True when the extracted layout looks like this bank's statement.
  bool matches(List<PdfLayoutLine> lines);

  StatementExtraction parse({
    required List<PdfLayoutLine> lines,
    required String fileFingerprint,
    String? fileName,
  });
}
