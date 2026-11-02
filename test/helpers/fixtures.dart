import 'package:joint_expenses/core/utils/money.dart';
import 'package:joint_expenses/data/models/category.dart';
import 'package:joint_expenses/data/models/expense_scope.dart';
import 'package:joint_expenses/data/models/household.dart';
import 'package:joint_expenses/data/models/profile.dart';
import 'package:joint_expenses/data/models/transaction.dart';
import 'package:joint_expenses/data/models/transaction_type.dart';

/// Shared test data mirroring the example in the specification:
/// User 1 income 45,000 / expenses 15,000; User 2 income 30,000 / expenses 10,000.
abstract final class Fixtures {
  static const householdId = 'hh-1';
  static const user1 = 'user-1';
  static const user2 = 'user-2';

  static const household = Household(
    id: householdId,
    name: 'Our Finances',
    ownerId: user1,
    currency: 'PHP',
  );

  static const profile1 = Profile(id: user1, displayName: 'Michiko', email: 'm@example.com');
  static const profile2 = Profile(id: user2, displayName: 'Alex', email: 'a@example.com');

  static const Map<String, String> memberNames = {user1: 'Michiko', user2: 'Alex'};

  static const salary = CategoryModel(
    id: 'cat-salary',
    householdId: householdId,
    name: 'Salary',
    type: TransactionType.income,
    icon: 'payments',
    color: '#16A34A',
  );
  static const food = CategoryModel(
    id: 'cat-food',
    householdId: householdId,
    name: 'Food & Drinks',
    type: TransactionType.expense,
    icon: 'restaurant',
    color: '#F97316',
  );
  static const rent = CategoryModel(
    id: 'cat-rent',
    householdId: householdId,
    name: 'Rent',
    type: TransactionType.expense,
    icon: 'home',
    color: '#6366F1',
  );
  static const transport = CategoryModel(
    id: 'cat-transport',
    householdId: householdId,
    name: 'Transportation',
    type: TransactionType.expense,
    icon: 'directions_bus',
    color: '#0EA5E9',
  );

  static const List<CategoryModel> categories = [salary, food, rent, transport];

  static Map<String, CategoryModel> get categoryMap => {for (final c in categories) c.id: c};

  static TransactionModel tx({
    required String id,
    required String userId,
    required CategoryModel category,
    required String amount,
    required DateTime date,
    String? description,
    DateTime? createdAt,
    ExpenseScope expenseScope = ExpenseScope.personal,
    String? assignedUserId,
    DateTime? jointPaidAt,
  }) {
    return TransactionModel(
      id: id,
      householdId: householdId,
      userId: userId,
      type: category.type,
      amount: Money.parse(amount),
      categoryId: category.id,
      description: description,
      transactionDate: date,
      createdAt: createdAt ?? date,
      category: category,
      userDisplayName: memberNames[userId],
      expenseScope: expenseScope,
      assignedUserId: assignedUserId ?? (expenseScope == ExpenseScope.personal ? userId : null),
      jointPaidAt: jointPaidAt,
    );
  }

  /// November 2026 sample month.
  static final DateTime nov1 = DateTime(2026, 11, 1);
  static final DateTime nov5 = DateTime(2026, 11, 5);
  static final DateTime nov10 = DateTime(2026, 11, 10);
  static final DateTime nov12 = DateTime(2026, 11, 12);

  static List<TransactionModel> specExample() => [
        tx(id: 't1', userId: user1, category: salary, amount: '45000', date: nov1, description: 'Salary'),
        tx(id: 't2', userId: user2, category: salary, amount: '30000', date: nov1),
        tx(id: 't3', userId: user1, category: rent, amount: '10000', date: nov5, description: 'Rent'),
        tx(id: 't4', userId: user1, category: food, amount: '5000', date: nov10, description: 'Groceries'),
        tx(id: 't5', userId: user2, category: food, amount: '7500', date: nov10, description: 'Dinner'),
        tx(id: 't6', userId: user2, category: transport, amount: '2500', date: nov12, description: 'Grab'),
      ];
}
