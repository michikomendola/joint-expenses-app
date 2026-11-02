import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';

enum DetectedLineType {
  purchase,
  installmentCharge,
  installmentPurchase,
  payment,
  refund,
  financeCharge,
  bankFee,
  summary;

  String get dbValue => switch (this) {
        DetectedLineType.purchase => 'purchase',
        DetectedLineType.installmentCharge => 'installment_charge',
        DetectedLineType.installmentPurchase => 'installment_purchase',
        DetectedLineType.payment => 'payment',
        DetectedLineType.refund => 'refund',
        DetectedLineType.financeCharge => 'finance_charge',
        DetectedLineType.bankFee => 'bank_fee',
        DetectedLineType.summary => 'summary',
      };

  bool get isImportCandidate =>
      this == DetectedLineType.purchase ||
      this == DetectedLineType.installmentCharge ||
      this == DetectedLineType.refund;

  String get label => switch (this) {
        DetectedLineType.purchase => 'Purchase',
        DetectedLineType.installmentCharge => 'Installment',
        DetectedLineType.installmentPurchase => 'Installment purchase',
        DetectedLineType.payment => 'Payment',
        DetectedLineType.refund => 'Refund / reversal',
        DetectedLineType.financeCharge => 'Finance charge',
        DetectedLineType.bankFee => 'Bank fee',
        DetectedLineType.summary => 'Summary',
      };
}

enum ReviewStatus {
  needsReview,
  classified,
  excluded,
  alreadyImported,
  possibleDuplicate,
  needsAttention;

  String get dbValue => switch (this) {
        ReviewStatus.needsReview => 'needs_review',
        ReviewStatus.classified => 'classified',
        ReviewStatus.excluded => 'excluded',
        ReviewStatus.alreadyImported => 'already_imported',
        ReviewStatus.possibleDuplicate => 'possible_duplicate',
        ReviewStatus.needsAttention => 'needs_attention',
      };

  String get label => switch (this) {
        ReviewStatus.needsReview => 'Needs review',
        ReviewStatus.classified => 'Ready',
        ReviewStatus.excluded => 'Excluded',
        ReviewStatus.alreadyImported => 'Already imported',
        ReviewStatus.possibleDuplicate => 'Possible duplicate',
        ReviewStatus.needsAttention => 'Needs attention',
      };
}

enum CardKind {
  principal,
  supplementary,
  unknown;

  String get dbValue => name;
  String get label => switch (this) {
        CardKind.principal => 'Principal',
        CardKind.supplementary => 'Supplementary',
        CardKind.unknown => 'Card',
      };
}

@immutable
class DetectedCardholder {
  const DetectedCardholder({
    required this.identifierHash,
    required this.maskedIdentifier,
    required this.displayName,
    required this.kind,
    this.mappedUserId,
    this.kindConfirmed = true,
  });

  final String identifierHash;
  final String maskedIdentifier;
  final String displayName;
  final CardKind kind;
  final String? mappedUserId;
  final bool kindConfirmed;

  DetectedCardholder copyWith({
    CardKind? kind,
    String? mappedUserId,
    bool clearMappedUser = false,
    bool? kindConfirmed,
  }) =>
      DetectedCardholder(
        identifierHash: identifierHash,
        maskedIdentifier: maskedIdentifier,
        displayName: displayName,
        kind: kind ?? this.kind,
        mappedUserId: clearMappedUser ? null : (mappedUserId ?? this.mappedUserId),
        kindConfirmed: kindConfirmed ?? this.kindConfirmed,
      );
}

@immutable
class InstallmentSummaryEntry {
  const InstallmentSummaryEntry({
    required this.merchantName,
    required this.normalizedMerchant,
    this.originalPurchaseDate,
    this.originalPurchaseAmount,
    this.remainingBalance,
    this.lastPaymentDate,
  });

  final String merchantName;
  final String normalizedMerchant;
  final DateTime? originalPurchaseDate;
  final Money? originalPurchaseAmount;
  final Money? remainingBalance;
  final DateTime? lastPaymentDate;
}

@immutable
class ExtractedLine {
  const ExtractedLine({
    required this.id,
    required this.sourcePage,
    required this.sourceRow,
    required this.rawText,
    required this.detectedType,
    required this.confidence,
    this.transactionDate,
    this.postDate,
    this.description,
    this.amount,
    this.currency = 'PHP',
    this.cardholderHash,
    this.installmentNumber,
    this.totalInstallments,
    this.originalCurrency,
    this.originalAmount,
    this.summary,
  });

  final String id;
  final int sourcePage;
  final String sourceRow;
  final String rawText;
  final DetectedLineType detectedType;
  final double confidence;
  final DateTime? transactionDate;
  final DateTime? postDate;
  final String? description;
  final Money? amount;
  final String currency;
  final String? cardholderHash;
  final int? installmentNumber;
  final int? totalInstallments;
  final String? originalCurrency;
  final Money? originalAmount;
  final InstallmentSummaryEntry? summary;

  bool get isInstallment => detectedType == DetectedLineType.installmentCharge;

  String get normalizedMerchant => normalizeMerchant(description ?? '');
}

@immutable
class StatementExtraction {
  const StatementExtraction({
    required this.bankName,
    required this.fingerprint,
    required this.currency,
    required this.cardholders,
    required this.lines,
    required this.installmentSummaries,
    this.statementDate,
    this.paymentDueDate,
    this.billingPeriodStart,
    this.billingPeriodEnd,
    this.statementReference,
    this.fileName,
    this.warnings = const [],
  });

  final String bankName;
  final String fingerprint;
  final String currency;
  final DateTime? statementDate;
  final DateTime? paymentDueDate;
  final DateTime? billingPeriodStart;
  final DateTime? billingPeriodEnd;
  final String? statementReference;
  final String? fileName;
  final List<DetectedCardholder> cardholders;
  final List<ExtractedLine> lines;
  final List<InstallmentSummaryEntry> installmentSummaries;
  final List<String> warnings;

  List<ExtractedLine> get importCandidates =>
      lines.where((l) => l.detectedType.isImportCandidate).toList(growable: false);

  List<ExtractedLine> get installmentCharges => lines
      .where((l) => l.detectedType == DetectedLineType.installmentCharge)
      .toList(growable: false);

  Money get installmentChargeTotal => installmentCharges.fold<Money>(
        Money.zero,
        (sum, l) => sum + (l.amount ?? Money.zero),
      );

  Money get remainingInstallmentBalance => installmentSummaries.fold<Money>(
        Money.zero,
        (sum, s) => sum + (s.remainingBalance ?? Money.zero),
      );
}

/// Lower-case, punctuation-stripped merchant key used for matching.
String normalizeMerchant(String input) {
  var text = input.toLowerCase();
  text = text.replaceAll(RegExp(r'\s+:\s+\d{1,2}/\d{1,2}\s*$'), '');
  text = text.replaceAll(RegExp(r'https?://\S+'), '');
  text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Drop trailing city-like tokens that BPI appends after the merchant.
  const noise = {
    'ph', 'philippines', 'cebu', 'city', 'mandaue', 'mandaluyong', 'makati',
    'pasig', 'taguig', 'manila', 'singapore', 'stockholm', 'london', 'com',
    'https', 'wwwde', 'www',
  };
  final parts = text.split(' ').where((w) => w.isNotEmpty && !noise.contains(w)).toList();
  if (parts.isEmpty) return text;
  return parts.take(5).join(' ');
}
