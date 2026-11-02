import 'package:flutter/foundation.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import 'category.dart';
import 'expense_scope.dart';
import 'payment_method.dart';
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
    this.expenseScope = ExpenseScope.personal,
    this.assignedUserId,
    this.assignedDisplayName,
    this.sourceType = TransactionSource.manual,
    this.paymentMethod = PaymentMethod.cash,
    this.postDate,
    this.installmentPlanId,
    this.originalCurrency,
    this.originalAmount,
    this.jointPaidAt,
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
      expenseScope: ExpenseScope.fromString(json['expense_scope'] as String?),
      assignedUserId: json['assigned_user_id'] as String?,
      assignedDisplayName: json['assigned_profile'] is Map<String, dynamic>
          ? (json['assigned_profile'] as Map<String, dynamic>)['display_name'] as String?
          : null,
      sourceType: TransactionSource.fromString(json['source_type'] as String?),
      paymentMethod: PaymentMethod.fromString(json['payment_method'] as String?),
      postDate: json['post_date'] != null
          ? AppDateUtils.parseIsoDate(json['post_date'] as String)
          : null,
      installmentPlanId: json['installment_plan_id'] as String?,
      originalCurrency: json['original_currency'] as String?,
      originalAmount: json['original_amount'] != null
          ? Money.fromJson(json['original_amount'])
          : null,
      jointPaidAt: json['joint_paid_at'] != null
          ? DateTime.tryParse(json['joint_paid_at'] as String)?.toLocal()
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
  final ExpenseScope expenseScope;
  final String? assignedUserId;
  final String? assignedDisplayName;
  final TransactionSource sourceType;
  final PaymentMethod paymentMethod;
  final DateTime? postDate;
  final String? installmentPlanId;
  final String? originalCurrency;
  final Money? originalAmount;

  /// Set when a joint expense has been marked paid. Null means unpaid.
  final DateTime? jointPaidAt;

  bool get isIncome => type.isIncome;
  bool get isExpense => type.isExpense;
  bool get isJointScope => expenseScope == ExpenseScope.joint;
  bool get isJoint => isExpense && isJointScope;
  bool get isJointPaid => isJoint && jointPaidAt != null;

  /// Who bears a personal expense. Joint expenses have no owner.
  String? get expenseOwnerId =>
      !isExpense || isJoint ? null : (assignedUserId ?? userId);

  /// A personal income or expense that belongs to [userId].
  bool isPersonalFor(String userId) {
    if (isJointScope) return false;
    if (isIncome) return this.userId == userId;
    return (expenseOwnerId ?? this.userId) == userId;
  }

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
    ExpenseScope? expenseScope,
    String? assignedUserId,
    String? assignedDisplayName,
    PaymentMethod? paymentMethod,
    DateTime? jointPaidAt,
    bool clearJointPaid = false,
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
        expenseScope: expenseScope ?? this.expenseScope,
        assignedUserId: assignedUserId ?? this.assignedUserId,
        assignedDisplayName: assignedDisplayName ?? this.assignedDisplayName,
        sourceType: sourceType,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        postDate: postDate,
        installmentPlanId: installmentPlanId,
        originalCurrency: originalCurrency,
        originalAmount: originalAmount,
        jointPaidAt: clearJointPaid ? null : (jointPaidAt ?? this.jointPaidAt),
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
    this.paymentMethod = PaymentMethod.cash,
    this.expenseScope = ExpenseScope.personal,
    this.assignedUserId,
  });

  final TransactionType type;
  final Money amount;
  final String categoryId;
  final DateTime transactionDate;
  final String? description;
  final PaymentMethod paymentMethod;
  final ExpenseScope expenseScope;
  final String? assignedUserId;

  Map<String, dynamic> toJson({String? userId}) {
    final personal = expenseScope == ExpenseScope.personal;
    return {
      'type': type.dbValue,
      'amount': amount.toDecimalString(),
      'category_id': categoryId,
      'description': description?.trim().isEmpty == true ? null : description?.trim(),
      'transaction_date': AppDateUtils.toIsoDate(transactionDate),
      'payment_method': type.isExpense ? paymentMethod.dbValue : PaymentMethod.cash.dbValue,
      'expense_scope': expenseScope.dbValue,
      'assigned_user_id': personal ? (assignedUserId ?? userId) : null,
    };
  }

  Map<String, dynamic> toInsertJson({
    required String householdId,
    required String userId,
  }) =>
      {
        ...toJson(userId: userId),
        'household_id': householdId,
        'user_id': userId,
        'source_type': 'manual',
      };
}
