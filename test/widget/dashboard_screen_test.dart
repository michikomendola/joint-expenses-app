import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/date_utils.dart';
import 'package:joint_expenses/core/widgets/skeleton.dart';
import 'package:joint_expenses/data/models/transaction.dart';
import 'package:joint_expenses/features/dashboard/application/dashboard_providers.dart';
import 'package:joint_expenses/features/dashboard/presentation/dashboard_screen.dart';
import 'package:joint_expenses/features/transactions/presentation/widgets/transaction_tile.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

class _FixedMonth extends SelectedMonthNotifier {
  @override
  YearMonth build() => const YearMonth(2026, 11);
}

void main() {
  group('DashboardScreen', () {
    testWidgets('shows combined balance, income and expenses from real data', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: Fixtures.specExample(),
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Our Finances'), findsOneWidget);
      expect(find.textContaining('Michiko'), findsWidgets); // greeting
      expect(find.text('Available Balance'), findsOneWidget);

      // Remaining Balance = 75,000 − 25,000
      expect(find.text('₱50,000.00'), findsOneWidget);
      expect(find.text('₱75,000.00'), findsOneWidget);
      expect(find.text('₱25,000.00'), findsOneWidget);
    });

    testWidgets('renders spending breakdown with percentages', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: Fixtures.specExample(),
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Spending Breakdown'), findsOneWidget);
      expect(find.text('Food & Drinks'), findsWidgets);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
    });

    testWidgets('lists the five most recent transactions with who added them', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: Fixtures.specExample(),
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.byType(TransactionTile), findsNWidgets(5));
      expect(find.text('Grab'), findsOneWidget);
      expect(find.textContaining('Paid by Alex'), findsWidgets);
      expect(find.textContaining('Paid by You'), findsWidgets);
      expect(find.text('- ₱2,500.00'), findsOneWidget);
    });

    testWidgets('shows empty states when there are no transactions', (tester) async {
      await pumpApp(
        tester,
        const DashboardScreen(),
        transactions: const <TransactionModel>[],
        overrides: [selectedMonthProvider.overrideWith(_FixedMonth.new)],
      );
      await tester.pumpAndSettle();

      expect(find.text('₱0.00'), findsNWidgets(3)); // balance, income, expenses
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
