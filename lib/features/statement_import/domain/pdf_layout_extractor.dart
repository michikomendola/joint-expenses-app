import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'pdf_tokens.dart';

class PdfExtractionException implements Exception {
  const PdfExtractionException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Layout-aware extractor: inflates PDF content streams and reads `Tm` / `Td` /
/// `Tj` operators. This is not a full PDF renderer — it is enough for
/// selectable-text bank statements such as BPI SOAs.
class PdfLayoutExtractor {
  static List<PdfLayoutLine> extract(Uint8List bytes) {
    if (bytes.length < 5 ||
        String.fromCharCodes(bytes.sublist(0, 5)) != '%PDF-') {
      throw const PdfExtractionException('invalid_pdf', 'This file is not a valid PDF.');
    }

    final latin = latin1.decode(bytes, allowInvalid: true);
    if (latin.contains('/Encrypt')) {
      throw const PdfExtractionException(
        'password_protected',
        'This statement is password-protected. Export an unlocked copy from your bank and try again.',
      );
    }

    final tokens = <PdfTextToken>[];
    var page = 0;
    final streamRe = RegExp(r'stream\r?\n');
    var searchFrom = 0;
    while (true) {
      final start = streamRe.firstMatch(latin.substring(searchFrom));
      if (start == null) break;
      final streamStart = searchFrom + start.end;
      final end = latin.indexOf('endstream', streamStart);
      if (end < 0) break;
      var raw = latin.substring(streamStart, end);
      if (raw.endsWith('\r\n')) {
        raw = raw.substring(0, raw.length - 2);
      } else if (raw.endsWith('\n') || raw.endsWith('\r')) {
        raw = raw.substring(0, raw.length - 1);
      }
      final rawBytes = Uint8List.fromList(latin1.encode(raw));
      String? content;
      if (rawBytes.length > 2 && rawBytes[0] == 0x78) {
        try {
          content = latin1.decode(const ZLibDecoder().decodeBytes(rawBytes), allowInvalid: true);
        } catch (_) {
          content = null;
        }
      }
      searchFrom = end + 9;
      if (content == null || !content.contains(' Tj')) continue;
      final pageTokens = _parseContent(content, page);
      if (pageTokens.isNotEmpty) {
        tokens.addAll(pageTokens);
        page += 1;
      }
    }

    if (tokens.isEmpty) {
      throw const PdfExtractionException(
        'image_only',
        'This looks like a scanned statement with no selectable text. OCR is not enabled yet — please upload a text PDF from your bank.',
      );
    }
    return clusterLines(tokens);
  }

  static List<PdfTextToken> _parseContent(String content, int page) {
    final tokens = <PdfTextToken>[];
    var x = 0.0;
    var y = 0.0;
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trimRight();
      final tm = RegExp(r'1\.00 0\.00 0\.00 1\.00\s+([0-9.]+)\s+([0-9.]+)\s+Tm')
          .firstMatch(line);
      if (tm != null) {
        x = double.parse(tm.group(1)!);
        y = double.parse(tm.group(2)!);
      }
      final td = RegExp(r'^([0-9.-]+)\s+([0-9.-]+)\s+Td').firstMatch(line.trimLeft());
      if (td != null) {
        x += double.parse(td.group(1)!);
        y += double.parse(td.group(2)!);
      }
      for (final match in RegExp(r'\(([^\)]*)\)\s*Tj').allMatches(line)) {
        final word = _unescape(match.group(1)!);
        if (word.isEmpty) continue;
        tokens.add(PdfTextToken(page: page, x: x, y: y, text: word));
      }
    }
    return tokens;
  }

  static String _unescape(String input) {
    return input
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\r', ' ');
  }

  /// Groups tokens that share a baseline (rounded to 1 pt) into reading-order lines.
  static List<PdfLayoutLine> clusterLines(List<PdfTextToken> tokens) {
    final buckets = <String, List<PdfTextToken>>{};
    for (final token in tokens) {
      final key = '${token.page}:${token.y.round()}';
      (buckets[key] ??= []).add(token);
    }
    final lines = buckets.entries.map((entry) {
      final parts = entry.key.split(':');
      final sorted = [...entry.value]..sort((a, b) => a.x.compareTo(b.x));
      return PdfLayoutLine(
        page: int.parse(parts[0]),
        y: double.parse(parts[1]),
        tokens: sorted,
      );
    }).toList()
      ..sort((a, b) {
        final byPage = a.page.compareTo(b.page);
        if (byPage != 0) return byPage;
        return b.y.compareTo(a.y);
      });
    return lines.where((l) => !l.isEmpty).toList(growable: false);
  }
}
