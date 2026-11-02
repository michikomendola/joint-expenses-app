import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:joint_expenses/core/theme/app_theme.dart';
import 'package:joint_expenses/core/utils/date_utils.dart';
import 'package:joint_expenses/data/models/category.dart';
import 'package:joint_expenses/data/models/household.dart';
import 'package:joint_expenses/data/models/profile.dart';
import 'package:joint_expenses/data/models/transaction.dart';
import 'package:joint_expenses/data/services/realtime_sync.dart';
import 'package:joint_expenses/features/authentication/application/auth_providers.dart';
import 'package:joint_expenses/features/categories/application/category_providers.dart';
import 'package:joint_expenses/data/models/joint_budget_share.dart';
import 'package:joint_expenses/features/dashboard/application/joint_budget_providers.dart';
import 'package:joint_expenses/features/households/application/household_providers.dart';
import 'package:joint_expenses/features/transactions/application/transaction_providers.dart';

import 'fixtures.dart';

/// Fake household notifier that never touches Supabase.
class FakeHouseholdNotifier extends CurrentHouseholdNotifier {
  FakeHouseholdNotifier(this._household);
  final Household? _household;

  @override
  Future<Household?> build() async => _household;
}

/// Wraps [child] in a MaterialApp + ProviderScope with offline overrides.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Household? household = Fixtures.household,
  Profile? profile = Fixtures.profile1,
  String? userId = Fixtures.user1,
  List<CategoryModel> categories = Fixtures.categories,
  List<HouseholdMember> members = const [],
  List<TransactionModel>? transactions,
  List<JointBudgetShare> shares = const [],
  Size size = const Size(390, 844),
}) async {
  await initializeDateFormatting();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        currentProfileProvider.overrideWith((ref) async => profile),
        currentHouseholdProvider.overrideWith(() => FakeHouseholdNotifier(household)),
        categoriesProvider.overrideWith((ref) async => categories),
        householdMembersProvider.overrideWith((ref) async => members),
        realtimeSyncProvider.overrideWithValue(null),
        if (transactions != null)
          monthTransactionsProvider.overrideWith(
            (ref, YearMonth? month) async => month == null
                ? transactions
                : transactions.where((t) => month.contains(t.transactionDate)).toList(),
          ),
        jointBudgetSharesProvider.overrideWith((ref) async => shares),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: child,
      ),
    ),
  );
}
