import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/date_utils.dart';
import 'package:joint_expenses/core/widgets/skeleton.dart';
import 'package:joint_expenses/data/models/expense_scope.dart';
import 'package:joint_expenses/data/models/transaction.dart';
import 'package:joint_expenses/features/dashboard/application/dashboard_providers.dart';
import 'package:joint_expenses/core/widgets/month_picker.dart';
import 'package:joint_expenses/features/dashboard/presentation/dashboard_screen.dart';
import 'package:joint_expenses/features/transactions/presentation/widgets/transaction_tile.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

class _FixedMonth extends SelectedMonthNotifier {
  @override
  YearMonth? build() => const YearMonth(2026, 11);
}

Future<void> openPersonal(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Switch account view'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Personal'));
  await tester.pumpAndSettle();
}

void main() {
  group('DashboardScreen', () {
    testWidgets('joint view hides personal rows and personal view shows them', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: Fixtures.specExample(),
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Joint account'), findsOneWidget);
      expect(find.textContaining('Michiko'), findsWidgets);
      expect(find.text('Joint leftover'), findsOneWidget);
      expect(find.text('Your personal leftover'), findsNothing);
      expect(find.text('₱75,000.00'), findsNothing);
      expect(find.text('₱0.00'), findsWidgets);

      await openPersonal(tester);

      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Your personal leftover'), findsOneWidget);
      expect(find.text('Joint leftover'), findsNothing);
      expect(find.text('₱45,000.00'), findsWidgets);
      expect(find.text('₱15,000.00'), findsWidgets);
      expect(find.text('₱30,000.00'), findsWidgets);
    });

    testWidgets('renders spending breakdown with percentages', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: Fixtures.specExample(),
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();
      await openPersonal(tester);

      expect(find.text('Spending Breakdown'), findsOneWidget);
      expect(find.text('Food & Drinks'), findsWidgets);
      expect(find.text('Rent'), findsWidgets);
      expect(find.text('66.7%'), findsOneWidget);
      expect(find.text('33.3%'), findsOneWidget);
    });

    testWidgets('lists the five most recent transactions with who added them', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: Fixtures.specExample(),
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();
      await openPersonal(tester);

      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.byType(TransactionTile), findsNWidgets(3));
      expect(find.text('Grab'), findsNothing);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.textContaining('Paid by You'), findsWidgets);
    });

    testWidgets('shows empty states when there are no transactions', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: const <TransactionModel>[],
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();

      expect(find.text('₱0.00'), findsWidgets); // balance, income, expenses, joint/total
      expect(find.text('No expenses yet'), findsOneWidget);
      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });

    testWidgets('shows skeletons while loading', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: Fixtures.specExample(),
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      // Before futures resolve.
      expect(find.byType(SkeletonBox), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonBox), findsNothing);
    });

    testWidgets('shows unused joint leftover that carries over', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: [
          Fixtures.tx(
            id: 'ji',
            userId: Fixtures.user1,
            category: Fixtures.salary,
            amount: '15000',
            date: DateTime(2026, 10, 1),
            expenseScope: ExpenseScope.joint,
          ),
          Fixtures.tx(
            id: 'je',
            userId: Fixtures.user1,
            category: Fixtures.rent,
            amount: '10000',
            date: DateTime(2026, 11, 5),
            expenseScope: ExpenseScope.joint,
          ),
        ],
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();
      expect(find.text('Unused budget · carries over'), findsOneWidget);
      expect(find.text('₱5,000.00'), findsWidgets);
    });

    testWidgets('offers to share a negative joint leftover', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: [
          Fixtures.tx(
            id: 'je2',
            userId: Fixtures.user1,
            category: Fixtures.rent,
            amount: '5000',
            date: DateTime(2026, 11, 5),
            expenseScope: ExpenseScope.joint,
          ),
        ],
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Overspent'), findsOneWidget);
      expect(find.text('Share this deficit'), findsOneWidget);
    });

    testWidgets('shows a check on a paid joint expense', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: [
          Fixtures.tx(
            id: 'paid',
            userId: Fixtures.user1,
            category: Fixtures.rent,
            amount: '1000',
            date: DateTime(2026, 11, 5),
            description: 'Rent share',
            expenseScope: ExpenseScope.joint,
            jointPaidAt: DateTime(2026, 11, 6),
          ),
        ],
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('calendar defaults to All time', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: Fixtures.specExample(),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(MonthChip, 'All time'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_month_rounded));
      await tester.pumpAndSettle();

      expect(find.text('This month'), findsOneWidget);
      expect(find.widgetWithText(MonthPickerSheet, 'All time'), findsOneWidget);
    });

    testWidgets('month chip shows the selected month', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: Fixtures.specExample(),
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();
      expect(find.text('Nov 2026'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    });
  });
}
