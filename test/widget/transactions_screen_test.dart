import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/date_utils.dart';
import 'package:joint_expenses/data/models/expense_scope.dart';
import 'package:joint_expenses/data/models/household.dart';
import 'package:joint_expenses/data/models/transaction.dart';
import 'package:joint_expenses/features/transactions/application/transaction_providers.dart';
import 'package:joint_expenses/features/transactions/domain/transaction_filter.dart';
import 'package:joint_expenses/features/transactions/presentation/transactions_screen.dart';
import 'package:joint_expenses/features/transactions/presentation/widgets/transaction_tile.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

class _FixedFilter extends TransactionFilterNotifier {
  @override
  TransactionFilter build() => const TransactionFilter(month: YearMonth(2026, 11));
}

final _members = [
  HouseholdMember(
    id: 'm1',
    householdId: Fixtures.householdId,
    userId: Fixtures.user1,
    role: MemberRole.owner,
    joinedAt: DateTime(2026),
    profile: Fixtures.profile1,
  ),
  HouseholdMember(
    id: 'm2',
    householdId: Fixtures.householdId,
    userId: Fixtures.user2,
    role: MemberRole.member,
    joinedAt: DateTime(2026),
    profile: Fixtures.profile2,
  ),
];

void main() {
  Future<void> pump(WidgetTester tester, {List<TransactionModel>? transactions}) async {
    await pumpApp(
      tester,
      const TransactionsScreen(),
      transactions: transactions ?? Fixtures.specExample(),
      members: _members,
      overrides: [transactionFilterProvider.overrideWith(_FixedFilter.new)],
    );
    await tester.pumpAndSettle();
  }

  Future<void> showPersonal(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Switch account view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal').last);
    await tester.pumpAndSettle();
  }

  group('TransactionsScreen', () {
    testWidgets('joint view hides personal rows', (tester) async {
      await pump(tester);

      expect(find.text('Joint account'), findsOneWidget);
      expect(find.byType(TransactionTile), findsNothing);
      expect(find.text('No joint transactions yet'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
      expect(find.text('Grab'), findsNothing);
    });

    testWidgets('personal view shows only the signed-in user', (tester) async {
      await pump(tester);
      await showPersonal(tester);

      expect(find.byType(TransactionTile), findsNWidgets(3));
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('+ ₱45,000.00'), findsWidgets);
      expect(find.text('Grab'), findsNothing);
      expect(find.text('Dinner'), findsNothing);
      expect(find.text('+ ₱30,000.00'), findsNothing);
      expect(find.textContaining('Food & Drinks · Personal · Cash · Paid by You'), findsOneWidget);
    });

    testWidgets('filters by type with chips', (tester) async {
      await pump(tester);
      await showPersonal(tester);

      Future<void> tapChip(String label) async {
        final chip = find.widgetWithText(ChoiceChip, label);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }

      await tapChip('Income');
      expect(find.byType(TransactionTile), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);

      await tapChip('Expenses');
      expect(find.byType(TransactionTile), findsNWidgets(2));

      await tapChip('All');
      expect(find.byType(TransactionTile), findsNWidgets(3));
    });

    testWidgets('search narrows the list and can be cleared', (tester) async {
      await pump(tester);
      await showPersonal(tester);

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'grocer');
      await tester.pumpAndSettle();

      expect(find.byType(TransactionTile), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nothing-here');
      await tester.pumpAndSettle();
      expect(find.text('No matching transactions'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionTile), findsNWidgets(3));
    });

    testWidgets('toggles sort order', (tester) async {
      await pump(tester);
      await showPersonal(tester);

      TransactionTile first() => tester.widget<TransactionTile>(find.byType(TransactionTile).first);
      expect(first().transaction.id, 't4');

      await tester.tap(find.byTooltip('Newest first'));
      await tester.pumpAndSettle();
      expect(first().transaction.transactionDate, Fixtures.nov1);
    });

    testWidgets('shows the empty state with a call to action', (tester) async {
      await pump(tester, transactions: const []);
      expect(find.text('No joint transactions yet'), findsOneWidget);
      expect(find.text('Add transaction'), findsOneWidget);
    });

    testWidgets('tapping a row opens the detail sheet; only owner can edit', (tester) async {
      await pump(
        tester,
        transactions: [
          ...Fixtures.specExample(),
          Fixtures.tx(
            id: 'tj',
            userId: Fixtures.user2,
            category: Fixtures.rent,
            amount: '8000',
            date: Fixtures.nov12,
            description: 'Utilities',
            expenseScope: ExpenseScope.joint,
          ),
        ],
      );

      expect(find.text('Utilities'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);

      await tester.tap(find.text('Utilities'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only Alex can edit'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await showPersonal(tester);
      expect(find.text('Utilities'), findsNothing);
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);
    });
  });
}
