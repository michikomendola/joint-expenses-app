import 'package:flutter/foundation.dart';

import '../../../core/utils/date_utils.dart';
import '../../../data/models/expense_scope.dart';
import 'installment_matcher.dart';
import 'statement_models.dart';

@immutable
class ReviewLine {
  const ReviewLine({
    required this.extracted,
    required this.status,
    this.expenseScope,
    this.assignedUserId,
    this.categoryId,
    this.matchedPlan,
    this.previouslyAssigned = false,
    this.selected = true,
    this.externalKey,
  });

  final ExtractedLine extracted;
  final ReviewStatus status;
  final ExpenseScope? expenseScope;
  final String? assignedUserId;
  final String? categoryId;
  final SavedInstallmentPlan? matchedPlan;
  final bool previouslyAssigned;
  final bool selected;
  final String? externalKey;

  bool get canImport =>
      selected &&
      extracted.detectedType.isImportCandidate &&
      extracted.transactionDate != null &&
      extracted.amount != null &&
      !extracted.amount!.isZero &&
      categoryId != null &&
      expenseScope != null &&
      (expenseScope != ExpenseScope.personal || assignedUserId != null) &&
      status != ReviewStatus.alreadyImported &&
      status != ReviewStatus.excluded &&
      status != ReviewStatus.needsAttention;

  bool get needsClassification =>
      extracted.detectedType.isImportCandidate &&
      status != ReviewStatus.alreadyImported &&
      status != ReviewStatus.excluded &&
      expenseScope == null;

  ReviewLine copyWith({
    ReviewStatus? status,
    ExpenseScope? expenseScope,
    String? assignedUserId,
    bool clearAssigned = false,
    bool clearScope = false,
    String? categoryId,
    SavedInstallmentPlan? matchedPlan,
    bool? previouslyAssigned,
    bool? selected,
    String? externalKey,
  }) =>
      ReviewLine(
        extracted: extracted,
        status: status ?? this.status,
        expenseScope: clearScope ? null : (expenseScope ?? this.expenseScope),
        assignedUserId: clearAssigned ? null : (assignedUserId ?? this.assignedUserId),
        categoryId: categoryId ?? this.categoryId,
        matchedPlan: matchedPlan ?? this.matchedPlan,
        previouslyAssigned: previouslyAssigned ?? this.previouslyAssigned,
        selected: selected ?? this.selected,
        externalKey: externalKey ?? this.externalKey,
      );

  Map<String, dynamic> toImportJson() => {
        'source_page': extracted.sourcePage.toString(),
        'source_row_identifier': extracted.sourceRow,
        'card_identifier_hash': extracted.cardholderHash,
        'transaction_date': extracted.transactionDate == null
            ? null
            : AppDateUtils.toIsoDate(extracted.transactionDate!),
        'post_date':
            extracted.postDate == null ? null : AppDateUtils.toIsoDate(extracted.postDate!),
        'description': extracted.description,
        'normalized_merchant': extracted.normalizedMerchant,
        'amount': extracted.amount?.toDecimalString(),
        'currency': extracted.currency,
        'detected_type': extracted.detectedType.dbValue,
        'installment_number': extracted.installmentNumber?.toString(),
        'total_installments': extracted.totalInstallments?.toString(),
        'category_id': categoryId,
        'expense_scope': expenseScope?.dbValue,
        'assigned_user_id': expenseScope == ExpenseScope.joint ? null : assignedUserId,
        'review_status': canImport ? ReviewStatus.classified.dbValue : status.dbValue,
        'external_transaction_key': externalKey,
        'original_currency': extracted.originalCurrency,
        'original_amount': extracted.originalAmount?.toDecimalString(),
        'original_purchase_date': extracted.summary?.originalPurchaseDate == null
            ? null
            : AppDateUtils.toIsoDate(extracted.summary!.originalPurchaseDate!),
        'original_purchase_amount':
            extracted.summary?.originalPurchaseAmount?.toDecimalString(),
        'remaining_balance': extracted.summary?.remainingBalance?.toDecimalString(),
        'last_payment_date': extracted.summary?.lastPaymentDate == null
            ? null
            : AppDateUtils.toIsoDate(extracted.summary!.lastPaymentDate!),
        'matched_installment_plan_id': matchedPlan?.id,
        'confidence_score': extracted.confidence.toString(),
        'payment_method': 'cc',
      };
}

abstract final class ExternalKeys {
  static String forLine({
    required String fingerprint,
    required ExtractedLine line,
  }) {
    final date = line.transactionDate == null
        ? ''
        : AppDateUtils.toIsoDate(line.transactionDate!);
    final post = line.postDate == null ? '' : AppDateUtils.toIsoDate(line.postDate!);
    final amount = line.amount?.toDecimalString() ?? '';
    final merchant = line.normalizedMerchant;
    final inst = '${line.installmentNumber ?? ''}/${line.totalInstallments ?? ''}';
    return '$fingerprint|$date|$post|$merchant|$amount|$inst|${line.sourceRow}';
  }
}
