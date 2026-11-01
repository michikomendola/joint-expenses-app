import 'package:flutter/foundation.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import 'category.dart';
import 'transaction_type.dart';

@immutable
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.transactionDate,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.userDisplayName,
  });

  /// Expects the joined shape:
  /// `*, category:categories(*), profile:profiles(display_name)`.
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    final profileJson = json['profile'];
    return TransactionModel(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      userId: json['user_id'] as String,
      type: TransactionType.fromString(json['type'] as String),
      amount: Money.fromJson(json['amount']),
      categoryId: json['category_id'] as String,
      description: (json['description'] as String?)?.trim().isEmpty == true
          ? null
          : json['description'] as String?,
      transactionDate: AppDateUtils.parseIsoDate(json['transaction_date'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)?.toLocal()
          : null,
      category: categoryJson is Map<String, dynamic>
          ? CategoryModel.fromJson(categoryJson)
          : null,
      userDisplayName: profileJson is Map<String, dynamic>
          ? profileJson['display_name'] as String?
          : null,
    );
  }

  final String id;
  final String householdId;
  final String userId;
  final TransactionType type;

  /// Always positive; [type] decides the direction.
  final Money amount;
  final String categoryId;
  final String? description;
  final DateTime transactionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Joined data (may be null if the join was not requested).
  final CategoryModel? category;
  final String? userDisplayName;

  bool get isIncome => type.isIncome;
  bool get isExpense => type.isExpense;

  /// What to show as the main label in lists.
  String get title =>
      description?.trim().isNotEmpty == true ? description!.trim() : categoryName;

  String get categoryName => category?.name ?? 'Uncategorised';

  /// Signed amount for balance math: + for income, − for expense.
  Money get signedAmount => isIncome ? amount : -amount;

  TransactionModel copyWith({
    TransactionType? type,
    Money? amount,
    String? categoryId,
    String? description,
    bool clearDescription = false,
    DateTime? transactionDate,
    CategoryModel? category,
    String? userDisplayName,
  }) =>
      TransactionModel(
        id: id,
        householdId: householdId,
        userId: userId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        description: clearDescription ? null : (description ?? this.description),
        transactionDate: transactionDate ?? this.transactionDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        category: category ?? this.category,
        userDisplayName: userDisplayName ?? this.userDisplayName,
      );

  @override
  bool operator ==(Object other) =>
      other is TransactionModel &&
      other.id == id &&
      other.type == type &&
      other.amount == amount &&
      other.categoryId == categoryId &&
      other.description == description &&
      other.transactionDate == transactionDate &&
      other.userId == userId &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id, type, amount, categoryId, description, transactionDate, userId, updatedAt,
      );

  @override
  String toString() => 'TransactionModel($id, ${type.name}, $amount)';
}

/// Payload for creating/updating a transaction.
@immutable
class TransactionInput {
  const TransactionInput({
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.transactionDate,
    this.description,
  });

  final TransactionType type;
  final Money amount;
  final String categoryId;
  final DateTime transactionDate;
  final String? description;

  Map<String, dynamic> toJson() => {
        'type': type.dbValue,
        'amount': amount.toDecimalString(),
        'category_id': categoryId,
        'description': description?.trim().isEmpty == true ? null : description?.trim(),
        'transaction_date': AppDateUtils.toIsoDate(transactionDate),
      };

  Map<String, dynamic> toInsertJson({
    required String householdId,
    required String userId,
  }) =>
      {
        ...toJson(),
        'household_id': householdId,
        'user_id': userId,
      };
}
