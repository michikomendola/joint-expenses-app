import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/date_utils.dart';
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

  group('TransactionsScreen', () {
    testWidgets('groups transactions by date and shows meta', (tester) async {
      await pump(tester);

      expect(find.byType(TransactionTile), findsNWidgets(6));
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.textContaining('Food & Drinks · Paid by You'), findsOneWidget);
      expect(find.textContaining('Received by Alex'), findsOneWidget);
      expect(find.text('+ ₱45,000.00'), findsOneWidget);
      expect(find.text('- ₱10,000.00'), findsOneWidget);

      // Four distinct days → four headers (upper-cased).
      expect(find.textContaining('NOV'), findsWidgets);
    });

    testWidgets('filters by type with chips', (tester) async {
      await pump(tester);

      Future<void> tapChip(String label) async {
        final chip = find.widgetWithText(ChoiceChip, label);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }

      await tapChip('Income');
      expect(find.byType(TransactionTile), findsNWidgets(2));
      expect(find.text('Groceries'), findsNothing);

      await tapChip('Expenses');
      expect(find.byType(TransactionTile), findsNWidgets(4));

      await tapChip('All');
      expect(find.byType(TransactionTile), findsNWidgets(6));
    });

    testWidgets('search narrows the list and can be cleared', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'grab');
      await tester.pumpAndSettle();

      expect(find.byType(TransactionTile), findsOneWidget);
      expect(find.text('Grab'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nothing-here');
      await tester.pumpAndSettle();
      expect(find.text('No matching transactions'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionTile), findsNWidgets(6));
    });

    testWidgets('toggles sort order', (tester) async {
      await pump(tester);

      TransactionTile first() => tester.widget<TransactionTile>(find.byType(TransactionTile).first);
      expect(first().transaction.id, 't6');

      await tester.tap(find.byTooltip('Newest first'));
      await tester.pumpAndSettle();
      expect(first().transaction.transactionDate, Fixtures.nov1);
    });

    testWidgets('shows the empty state with a call to action', (tester) async {
      await pump(tester, transactions: const []);
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Add transaction'), findsOneWidget);
    });

    testWidgets('tapping a row opens the detail sheet; only owner can edit', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Dinner')); // Alex's transaction
      await tester.pumpAndSettle();
      expect(find.textContaining('Only Alex can edit'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsNothing);
      await tester.tapAt(const Offset(10, 10)); // dismiss
      await tester.pumpAndSettle();

      await tester.tap(find.text('Groceries')); // own transaction
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);
    });
  });
}
