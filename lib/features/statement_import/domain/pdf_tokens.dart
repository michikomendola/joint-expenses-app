import 'package:flutter/foundation.dart';

/// A single positioned word extracted from a PDF content stream.
@immutable
class PdfTextToken {
  const PdfTextToken({
    required this.page,
    required this.x,
    required this.y,
    required this.text,
  });

  final int page;
  final double x;
  final double y;
  final String text;
}

/// Tokens on one baseline, already sorted left-to-right.
@immutable
class PdfLayoutLine {
  const PdfLayoutLine({
    required this.page,
    required this.y,
    required this.tokens,
  });

  final int page;
  final double y;
  final List<PdfTextToken> tokens;

  String get text => tokens.map((t) => t.text).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  bool get isEmpty => text.isEmpty;
}
