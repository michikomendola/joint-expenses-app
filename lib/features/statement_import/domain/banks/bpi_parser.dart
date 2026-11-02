import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../core/utils/money.dart';
import '../pdf_tokens.dart';
import '../statement_models.dart';
import 'bank_parser.dart';

/// Deterministic BPI Statement of Account parser.
///
/// Relies on section headers and table structure (cardholder boundaries,
/// "Transaction Date / Post Date / Description / Amount", installment
/// amortization, installment balance summary). It does not treat every
/// date-and-amount pair on the page as a purchase.
class BpiParser implements BankParser {
  @override
  String get bankId => 'bpi';

  @override
  String get displayName => 'BPI';

  static const _months = <String, int>{
    'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
    'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11,
    'december': 12, 'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static final _txRow = RegExp(
    r'^(January|February|March|April|May|June|July|August|September|October|November|December)\s+'
    r'(\d{1,2})\s+'
    r'(January|February|March|April|May|June|July|August|September|October|November|December)\s+'
    r'(\d{1,2})\s+'
    r'(.+?)\s+'
    r'(-?[\d,]+\.\d{2})$',
    caseSensitive: false,
  );

  static final _txRowNoAmount = RegExp(
    r'^(January|February|March|April|May|June|July|August|September|October|November|December)\s+'
    r'(\d{1,2})\s+'
    r'(January|February|March|April|May|June|July|August|September|October|November|December)\s+'
    r'(\d{1,2})\s+'
    r'(.+)$',
    caseSensitive: false,
  );

  static final _fxLine = RegExp(
    r'(U\.?S\.?\s*Dollar|USD|EUR|GBP|JPY|SGD|AUD|CAD|HKD|CNY|KRW)\s+'
    r'([\d,]+\.\d{2})\s+([\d,]+\.\d{2})',
    caseSensitive: false,
  );

  static final _installmentSuffix = RegExp(r'\s*:?\s*(\d{1,2})\s*/\s*(\d{1,2})\s*$');

  static final _cardholderHeader = RegExp(
    r'^(\d{4,6}-\d-\d{2}-\d+)\s*-\s*(.+)$',
  );

  static final _summaryRow = RegExp(
    r'^(\d{6})\s+(\d{6})\s+(.+?)\s+([\d,]+\.\d{2})\s+([\d,]+\.\d{2})$',
  );

  static const _excludeExact = {
    'previous balance',
    'ending balance',
    'past due',
    'past due amount',
    'unbilled installment amount',
    'total outstanding balance',
    'total amount due',
    'minimum amount due',
    'credit limit',
    'finance charge',
  };

  @override
  bool matches(List<PdfLayoutLine> lines) {
    final blob = lines.map((l) => l.text.toLowerCase()).join('\n');
    final hasBpi = blob.contains('bpi');
    final hasSoa = blob.contains('statement of account') ||
        blob.contains('statement date') ||
        blob.contains('bpi signature');
    final hasTable = blob.contains('transaction') && blob.contains('post date');
    return hasBpi && hasSoa && hasTable;
  }

  @override
  StatementExtraction parse({
    required List<PdfLayoutLine> lines,
    required String fileFingerprint,
    String? fileName,
  }) {
    final warnings = <String>[];
    final texts = lines.map((l) => l.text).toList(growable: false);

    final statementDate = _findLabeledDate(texts, 'STATEMENT DATE');
    final dueDate = _findLabeledDate(texts, 'PAYMENT DUE DATE');
    final reference = _findAfter(texts, 'Reference No.');
    final customerNumber = _findAfter(texts, 'CUSTOMER NUMBER');
    final accountName = _guessAccountName(texts);

    if (statementDate == null) {
      warnings.add('Statement date could not be read confidently.');
    }

    final year = statementDate?.year ?? DateTime.now().year;
    final statementMonth = statementDate?.month ?? DateTime.now().month;

    final cardholders = <DetectedCardholder>[];
    final linesOut = <ExtractedLine>[];
    final summaries = <InstallmentSummaryEntry>[];

    var inTransactions = false;
    var inInstallmentBlock = false;
    var inInstallmentPurchase = false;
    var inBalanceSummary = false;
    DetectedCardholder? currentCard;
    var cardOrder = 0;

    ExtractedLine? pendingFx;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = line.text;
      final lower = text.toLowerCase();

      if (lower.contains('installment balance summary')) {
        inBalanceSummary = true;
        inTransactions = false;
        inInstallmentBlock = false;
        inInstallmentPurchase = false;
        continue;
      }
      if (lower.startsWith('transaction') && lower.contains('post') && lower.contains('description')) {
        inTransactions = true;
        inBalanceSummary = false;
        continue;
      }
      if (lower == 'date' && i > 0 && lines[i - 1].text.toLowerCase().contains('transaction')) {
        continue;
      }
      if (_isNamedSection(lower, const ['purchases', 'retail purchases', 'other charges', 'credits', 'payments'])) {
        inInstallmentPurchase = false;
        inInstallmentBlock = false;
        continue;
      }
      if (_isNamedSection(lower, const ['installment purchase', 'installment purchases'])) {
        inInstallmentPurchase = true;
        inInstallmentBlock = false;
        inTransactions = true;
        continue;
      }
      if (_cardholderHeader.hasMatch(text)) {
        currentCard = _cardholderFrom(text, accountName, cardOrder, fileFingerprint);
        cardOrder += 1;
        if (!cardholders.any((c) => c.identifierHash == currentCard!.identifierHash)) {
          cardholders.add(currentCard);
        }
        inInstallmentBlock = false;
        inInstallmentPurchase = false;
        inTransactions = true;
        continue;
      }
      if (lower.startsWith('installment amortization')) {
        inInstallmentBlock = true;
        inInstallmentPurchase = false;
        continue;
      }

      if (inBalanceSummary) {
        final summary = _parseSummaryRow(text, year);
        if (summary != null) summaries.add(summary);
        continue;
      }

      if (!inTransactions) continue;

      if (pendingFx != null) {
        final fx = _fxLine.firstMatch(text);
        if (fx != null) {
          final billed = Money.tryParse(fx.group(3)!);
          final original = Money.tryParse(fx.group(2)!);
          if (billed != null) {
            linesOut.add(
              ExtractedLine(
                id: pendingFx.id,
                sourcePage: pendingFx.sourcePage,
                sourceRow: pendingFx.sourceRow,
                rawText: '${pendingFx.rawText} | $text',
                detectedType: pendingFx.detectedType,
                confidence: 0.92,
                transactionDate: pendingFx.transactionDate,
                postDate: pendingFx.postDate,
                description: pendingFx.description,
                amount: billed,
                cardholderHash: pendingFx.cardholderHash,
                originalCurrency: _fxCode(fx.group(1)!),
                originalAmount: original,
              ),
            );
            pendingFx = null;
            continue;
          }
        }
        linesOut.add(pendingFx);
        pendingFx = null;
      }

      final classified = _classifyRow(
        line: line,
        year: year,
        statementMonth: statementMonth,
        cardholder: currentCard,
        inInstallmentBlock: inInstallmentBlock,
        inInstallmentPurchase: inInstallmentPurchase,
      );
      if (classified == null) continue;

      if (classified.detectedType == DetectedLineType.purchase &&
          classified.amount == null &&
          classified.description != null) {
        pendingFx = classified;
        continue;
      }

      if (classified.detectedType == DetectedLineType.payment ||
          classified.detectedType == DetectedLineType.refund) {
        inInstallmentPurchase = false;
        inInstallmentBlock = false;
      } else if (classified.isInstallment) {
        inInstallmentBlock = true;
      } else if (classified.detectedType == DetectedLineType.purchase) {
        inInstallmentBlock = false;
      }

      linesOut.add(classified);
    }

    if (pendingFx != null) {
      warnings.add('A foreign-currency row was missing its billed peso amount.');
      linesOut.add(pendingFx.copyWithNeedsAttention());
    }

    final matched = _matchSummaries(linesOut, summaries);

    return StatementExtraction(
      bankName: displayName,
      fingerprint: fileFingerprint,
      currency: 'PHP',
      statementDate: statementDate,
      paymentDueDate: dueDate,
      statementReference: reference,
      fileName: fileName,
      cardholders: cardholders,
      lines: matched,
      installmentSummaries: summaries,
      warnings: [
        ...warnings,
        if (customerNumber != null) 'Customer number detected and stored as a hash only.',
      ],
    );
  }

  ExtractedLine? _classifyRow({
    required PdfLayoutLine line,
    required int year,
    required int statementMonth,
    required DetectedCardholder? cardholder,
    required bool inInstallmentBlock,
    required bool inInstallmentPurchase,
  }) {
    final text = line.text;
    final lower = text.toLowerCase();

    if (_excludeExact.any(lower.startsWith) && !_txRow.hasMatch(text)) {
      return null;
    }

    final withAmount = _txRow.firstMatch(text);
    final noAmount = withAmount == null ? _txRowNoAmount.firstMatch(text) : null;
    final match = withAmount ?? noAmount;
    if (match == null) return null;

    final txDate = _resolveDate(match.group(1)!, match.group(2)!, year, statementMonth);
    final postDate = _resolveDate(match.group(3)!, match.group(4)!, year, statementMonth);
    var description = match.group(5)!.trim();
    final amount = withAmount != null ? Money.tryParse(withAmount.group(6)!) : null;

    if (txDate == null) {
      return ExtractedLine(
        id: _lineId(line, description),
        sourcePage: line.page,
        sourceRow: 'p${line.page}:${line.y.round()}',
        rawText: text,
        detectedType: DetectedLineType.summary,
        confidence: 0.3,
        description: description,
        amount: amount,
        cardholderHash: cardholder?.identifierHash,
      );
    }

    final type = _typeFor(
      description,
      amount,
      inInstallmentBlock: inInstallmentBlock,
      inInstallmentPurchase: inInstallmentPurchase,
    );
    // A refund shown as a positive credit is still money coming back.
    final signedAmount = type == DetectedLineType.refund && amount != null && amount.isPositive
        ? -amount
        : amount;
    final inst = _installmentSuffix.firstMatch(description);
    var instNo = inst != null ? int.parse(inst.group(1)!) : null;
    var instTotal = inst != null ? int.parse(inst.group(2)!) : null;
    if (inst != null) {
      description = description.replaceFirst(_installmentSuffix, '').trim();
    }

    return ExtractedLine(
      id: _lineId(line, description),
      sourcePage: line.page,
      sourceRow: 'p${line.page}:${line.y.round()}',
      rawText: text,
      detectedType: type,
      confidence: signedAmount == null ? 0.55 : 0.9,
      transactionDate: txDate,
      postDate: postDate,
      description: description,
      amount: signedAmount,
      cardholderHash: cardholder?.identifierHash,
      installmentNumber: type == DetectedLineType.installmentCharge ? instNo : null,
      totalInstallments: type == DetectedLineType.installmentCharge ? instTotal : null,
    );
  }

  DetectedLineType _typeFor(
    String description,
    Money? amount, {
    required bool inInstallmentBlock,
    required bool inInstallmentPurchase,
  }) {
    final lower = description.toLowerCase();
    if (lower.contains('payment') && lower.contains('thank you')) {
      return DetectedLineType.payment;
    }
    if (lower.contains('reversal') || lower.contains('refund') || lower.contains('rebate')) {
      return DetectedLineType.refund;
    }
    if (lower.contains('finance charge') || lower.contains('late payment') || lower.contains('interest')) {
      return DetectedLineType.financeCharge;
    }
    if (inInstallmentPurchase) {
      return DetectedLineType.installmentPurchase;
    }
    if (_installmentSuffix.hasMatch(description) || inInstallmentBlock && _installmentSuffix.hasMatch(description)) {
      return DetectedLineType.installmentCharge;
    }
    if (amount != null && amount.isNegative) {
      return DetectedLineType.refund;
    }
    return DetectedLineType.purchase;
  }

  bool _isNamedSection(String lower, List<String> names) {
    final normalized = lower.replaceAll(':', '').trim();
    return names.contains(normalized);
  }

  InstallmentSummaryEntry? _parseSummaryRow(String text, int fallbackYear) {
    if (text.toLowerCase().startsWith('total ')) return null;
    if (text.toLowerCase().contains('transaction last payment')) return null;
    final match = _summaryRow.firstMatch(text);
    if (match == null) return null;
    final purchase = _parseCompactDate(match.group(1)!, fallbackYear);
    final lastPay = _parseCompactDate(match.group(2)!, fallbackYear);
    final merchant = match.group(3)!.trim();
    return InstallmentSummaryEntry(
      merchantName: merchant,
      normalizedMerchant: normalizeMerchant(merchant),
      originalPurchaseDate: purchase,
      lastPaymentDate: lastPay,
      originalPurchaseAmount: Money.tryParse(match.group(4)!),
      remainingBalance: Money.tryParse(match.group(5)!),
    );
  }

  List<ExtractedLine> _matchSummaries(
    List<ExtractedLine> lines,
    List<InstallmentSummaryEntry> summaries,
  ) {
    return lines.map((line) {
      if (!line.isInstallment) return line;
      final matches = summaries.where((s) {
        return _merchantSimilar(s.normalizedMerchant, line.normalizedMerchant);
      }).toList();
      if (matches.length == 1) {
        return ExtractedLine(
          id: line.id,
          sourcePage: line.sourcePage,
          sourceRow: line.sourceRow,
          rawText: line.rawText,
          detectedType: line.detectedType,
          confidence: line.confidence,
          transactionDate: line.transactionDate,
          postDate: line.postDate,
          description: line.description,
          amount: line.amount,
          currency: line.currency,
          cardholderHash: line.cardholderHash,
          installmentNumber: line.installmentNumber,
          totalInstallments: line.totalInstallments,
          originalCurrency: line.originalCurrency,
          originalAmount: line.originalAmount,
          summary: matches.single,
        );
      }
      return line;
    }).toList(growable: false);
  }

  bool _merchantSimilar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    return a.startsWith(b) || b.startsWith(a) || a.contains(b) || b.contains(a);
  }

  DetectedCardholder _cardholderFrom(
    String text,
    String? accountName,
    int order,
    String fingerprint,
  ) {
    final match = _cardholderHeader.firstMatch(text)!;
    final rawId = match.group(1)!;
    final name = _titleCase(match.group(2)!.trim());
    final last4 = rawId.replaceAll(RegExp(r'\D'), '');
    final masked = last4.length >= 4 ? '****${last4.substring(last4.length - 4)}' : '****';
    final hash = sha256.convert(utf8.encode('$fingerprint|$rawId')).toString();
    final isPrincipal = order == 0 ||
        (accountName != null && _namesOverlap(accountName, name));
    return DetectedCardholder(
      identifierHash: hash,
      maskedIdentifier: masked,
      displayName: name,
      kind: isPrincipal ? CardKind.principal : CardKind.supplementary,
      kindConfirmed: accountName != null || order > 0,
    );
  }

  DateTime? _findLabeledDate(List<String> texts, String label) {
    for (final text in texts) {
      final idx = text.toUpperCase().indexOf(label.toUpperCase());
      if (idx < 0) continue;
      final rest = text.substring(idx + label.length).trim();
      final parsed = _parseLongDate(rest);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String? _findAfter(List<String> texts, String label) {
    for (final text in texts) {
      final idx = text.toUpperCase().indexOf(label.toUpperCase());
      if (idx < 0) continue;
      final rest = text.substring(idx + label.length).trim();
      if (rest.isNotEmpty) return rest;
    }
    return null;
  }

  String? _guessAccountName(List<String> texts) {
    for (var i = 0; i < texts.length; i++) {
      if (texts[i].toUpperCase().contains('STATEMENT DATE') && i + 1 < texts.length) {
        final next = texts[i + 1].trim();
        if (!next.toUpperCase().contains('PAYMENT') && next.split(' ').length >= 2) {
          return next;
        }
      }
    }
    return null;
  }

  DateTime? _parseLongDate(String input) {
    final match = RegExp(
      r'(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(\d{4})',
      caseSensitive: false,
    ).firstMatch(input);
    if (match == null) return null;
    final month = _months[match.group(1)!.toLowerCase()];
    if (month == null) return null;
    return DateTime(int.parse(match.group(3)!), month, int.parse(match.group(2)!));
  }

  DateTime? _resolveDate(String monthName, String dayText, int statementYear, int statementMonth) {
    final month = _months[monthName.toLowerCase()];
    final day = int.tryParse(dayText);
    if (month == null || day == null) return null;
    var year = statementYear;
    // Statement in January can still list December purchases from last year.
    if (statementMonth <= 2 && month >= 11) year -= 1;
    return DateTime(year, month, day);
  }

  DateTime? _parseCompactDate(String mmddyy, int fallbackYear) {
    if (mmddyy.length != 6) return null;
    final month = int.tryParse(mmddyy.substring(0, 2));
    final day = int.tryParse(mmddyy.substring(2, 4));
    final yy = int.tryParse(mmddyy.substring(4, 6));
    if (month == null || day == null || yy == null) return null;
    final year = yy >= 70 ? 1900 + yy : 2000 + yy;
    return DateTime(year, month, day);
  }

  String _fxCode(String raw) {
    final t = raw.toUpperCase().replaceAll('.', '').replaceAll(' ', '');
    if (t.contains('USD') || t.contains('USDOLLAR') || t.contains('DOLLAR')) return 'USD';
    if (t.contains('EUR')) return 'EUR';
    if (t.contains('GBP')) return 'GBP';
    if (t.contains('JPY')) return 'JPY';
    return t.length >= 3 ? t.substring(0, 3) : 'USD';
  }

  bool _namesOverlap(String a, String b) {
    final ta = a.toUpperCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final tb = b.toUpperCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    return ta.intersection(tb).length >= 2;
  }

  String _titleCase(String input) => input
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  String _lineId(PdfLayoutLine line, String description) =>
      'p${line.page}-y${line.y.round()}-${description.hashCode.toUnsigned(32).toRadixString(16)}';
}

extension on ExtractedLine {
  ExtractedLine copyWithNeedsAttention() => ExtractedLine(
        id: id,
        sourcePage: sourcePage,
        sourceRow: sourceRow,
        rawText: rawText,
        detectedType: DetectedLineType.summary,
        confidence: 0.2,
        transactionDate: transactionDate,
        postDate: postDate,
        description: description,
        amount: amount,
        currency: currency,
        cardholderHash: cardholderHash,
        installmentNumber: installmentNumber,
        totalInstallments: totalInstallments,
        originalCurrency: originalCurrency,
        originalAmount: originalAmount,
        summary: summary,
      );
}
