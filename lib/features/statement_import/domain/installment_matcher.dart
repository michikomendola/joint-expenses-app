import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';
import 'statement_models.dart';

@immutable
class SavedInstallmentPlan {
  const SavedInstallmentPlan({
    required this.id,
    required this.householdId,
    required this.normalizedMerchant,
    required this.monthlyAmount,
    required this.totalInstallments,
    required this.expenseScope,
    this.cardholderId,
    this.assignedUserId,
    this.originalPurchaseDate,
    this.originalPurchaseAmount,
    this.categoryId,
    this.status = 'active',
  });

  final String id;
  final String householdId;
  final String normalizedMerchant;
  final Money monthlyAmount;
  final int totalInstallments;
  final String expenseScope;
  final String? cardholderId;
  final String? assignedUserId;
  final DateTime? originalPurchaseDate;
  final Money? originalPurchaseAmount;
  final String? categoryId;
  final String status;
}

enum PlanMatchKind { none, confident, ambiguous }

@immutable
class PlanMatch {
  const PlanMatch(this.kind, [this.plan]);
  final PlanMatchKind kind;
  final SavedInstallmentPlan? plan;

  bool get isConfident => kind == PlanMatchKind.confident && plan != null;
}

/// Confidence-based matching. Merchant name alone is never unique.
abstract final class InstallmentMatcher {
  static const int amountToleranceMinor = 2; // 2 centavos

  static PlanMatch match({
    required ExtractedLine charge,
    required List<SavedInstallmentPlan> plans,
    String? cardholderId,
  }) {
    if (!charge.isInstallment || charge.amount == null || charge.totalInstallments == null) {
      return const PlanMatch(PlanMatchKind.none);
    }

    final candidates = plans.where((plan) {
      if (plan.totalInstallments != charge.totalInstallments) return false;
      if ((plan.monthlyAmount.minor - charge.amount!.minor).abs() > amountToleranceMinor) {
        return false;
      }
      if (!_merchantClose(plan.normalizedMerchant, charge.normalizedMerchant)) {
        return false;
      }
      if (cardholderId != null &&
          plan.cardholderId != null &&
          plan.cardholderId != cardholderId) {
        return false;
      }
      final summary = charge.summary;
      if (summary?.originalPurchaseAmount != null && plan.originalPurchaseAmount != null) {
        if ((summary!.originalPurchaseAmount!.minor - plan.originalPurchaseAmount!.minor).abs() >
            amountToleranceMinor) {
          return false;
        }
      }
      if (summary?.originalPurchaseDate != null && plan.originalPurchaseDate != null) {
        if (!_sameDay(summary!.originalPurchaseDate!, plan.originalPurchaseDate!)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (candidates.isEmpty) return const PlanMatch(PlanMatchKind.none);
    if (candidates.length == 1) return PlanMatch(PlanMatchKind.confident, candidates.single);
    return const PlanMatch(PlanMatchKind.ambiguous);
  }

  static bool _merchantClose(String a, String b) {
    if (a == b) return true;
    if (a.isEmpty || b.isEmpty) return false;
    return a.startsWith(b) || b.startsWith(a);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
