import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/joint_budget_share.dart';
import '../../../data/models/transaction.dart';

/// Running joint leftover and the current user's personal leftover.
@immutable
class JointBudget {
  const JointBudget({
    required this.jointIncome,
    required this.jointExpense,
    required this.adjustments,
    required this.personalIncome,
    required this.personalExpense,
    this.lastShare,
  });

  static const JointBudget empty = JointBudget(
    jointIncome: Money.zero,
    jointExpense: Money.zero,
    adjustments: Money.zero,
    personalIncome: Money.zero,
    personalExpense: Money.zero,
  );

  final Money jointIncome;
  final Money jointExpense;
  final Money adjustments;
  final Money personalIncome;
  final Money personalExpense;
  final JointBudgetShare? lastShare;

  /// All-time joint income − joint expenses + shared-deficit adjustments.
  Money get leftover => jointIncome - jointExpense + adjustments;

  Money get personalLeftover => personalIncome - personalExpense;

  bool get isUnused => leftover.isPositive;
  bool get isOverspent => leftover.isNegative;
  bool get isReset => leftover.isZero && lastShare != null;
}

abstract final class JointBudgetCalculator {
  static JointBudget compute({
    required List<TransactionModel> transactions,
    required List<JointBudgetShare> shares,
    String? currentUserId,
  }) {
    var jointIncome = Money.zero;
    var jointExpense = Money.zero;
    var personalIncome = Money.zero;
    var personalExpense = Money.zero;

    for (final t in transactions) {
      if (t.isJointScope) {
        if (t.isIncome) {
          jointIncome += t.amount;
        } else {
          jointExpense += t.amount;
        }
        continue;
      }
      if (currentUserId == null) continue;
      if (t.isIncome && t.userId == currentUserId) {
        personalIncome += t.amount;
      } else if (t.isExpense && t.expenseOwnerId == currentUserId) {
        personalExpense += t.amount;
      }
    }

    final adjustments = Money.sum(shares.map((s) => s.adjustmentAmount));
    final sorted = [...shares]..sort((a, b) => b.sharedAt.compareTo(a.sharedAt));

    return JointBudget(
      jointIncome: jointIncome,
      jointExpense: jointExpense,
      adjustments: adjustments,
      personalIncome: personalIncome,
      personalExpense: personalExpense,
      lastShare: sorted.firstOrNull,
    );
  }
}
