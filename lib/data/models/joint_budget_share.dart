import 'package:flutter/foundation.dart';

import '../../core/utils/money.dart';

@immutable
class JointBudgetShare {
  const JointBudgetShare({
    required this.id,
    required this.householdId,
    required this.adjustmentAmount,
    required this.leftoverBefore,
    required this.sharedAt,
    required this.markedBy,
  });

  factory JointBudgetShare.fromJson(Map<String, dynamic> json) {
    return JointBudgetShare(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      adjustmentAmount: Money.fromJson(json['adjustment_amount']),
      leftoverBefore: Money.fromJson(json['leftover_before']),
      sharedAt: DateTime.parse(json['shared_at'] as String).toLocal(),
      markedBy: json['marked_by'] as String,
    );
  }

  final String id;
  final String householdId;
  final Money adjustmentAmount;
  final Money leftoverBefore;
  final DateTime sharedAt;
  final String markedBy;
}
