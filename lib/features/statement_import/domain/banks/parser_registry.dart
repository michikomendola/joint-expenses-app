import '../pdf_tokens.dart';
import 'bank_parser.dart';
import 'bpi_parser.dart';

class UnsupportedStatementException implements Exception {
  const UnsupportedStatementException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Ordered list of bank parsers. First match wins.
abstract final class BankParserRegistry {
  static final List<BankParser> parsers = [
    BpiParser(),
  ];

  static BankParser detect(List<PdfLayoutLine> lines) {
    for (final parser in parsers) {
      if (parser.matches(lines)) return parser;
    }
    throw const UnsupportedStatementException(
      'This statement layout is not supported yet. Joint Expenses currently reads BPI credit card statements.',
    );
  }
}
