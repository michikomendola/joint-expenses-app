import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/data/models/expense_scope.dart';
import 'package:joint_expenses/features/transactions/presentation/widgets/transaction_tile.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('swiping a joint expense reveals paid, edit, and delete icons', (tester) async {
    var paid = 0;
    var edited = 0;
    var deleted = 0;
    final transaction = Fixtures.tx(
      id: 'joint',
      userId: Fixtures.user1,
      category: Fixtures.rent,
      amount: '2500',
      date: DateTime(2026, 10, 21),
      description: 'Gintell',
      expenseScope: ExpenseScope.joint,
    );

    await pumpApp(
      tester,
      TransactionTile(
        transaction: transaction,
        currency: 'PHP',
        onTogglePaid: () => paid++,
        onEdit: () => edited++,
        onDelete: () => deleted++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Gintell'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Paid'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.text('Paid'), findsNothing);

    await tester.tap(find.byTooltip('Paid'));
    await tester.pumpAndSettle();
    expect(paid, 1);

    await tester.drag(find.text('Gintell'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(edited, 1);

    await tester.drag(find.text('Gintell'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('a paid joint expense reveals Unpaid and keeps the check', (tester) async {
    final transaction = Fixtures.tx(
      id: 'paid',
      userId: Fixtures.user1,
      category: Fixtures.rent,
      amount: '2500',
      date: DateTime(2026, 10, 21),
      description: 'Meralco',
      expenseScope: ExpenseScope.joint,
      jointPaidAt: DateTime(2026, 10, 22),
    );

    await pumpApp(
      tester,
      TransactionTile(
        transaction: transaction,
        currency: 'PHP',
        onTogglePaid: () {},
        onEdit: () {},
        onDelete: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.drag(find.text('Meralco'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unpaid'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('a personal expense reveals edit and delete, not paid', (tester) async {
    final transaction = Fixtures.tx(
      id: 'personal',
      userId: Fixtures.user1,
      category: Fixtures.food,
      amount: '701',
      date: DateTime(2026, 10, 21),
      description: 'Shopee',
    );

    await pumpApp(
      tester,
      Material(
        child: TransactionTile(
          transaction: transaction,
          currency: 'PHP',
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('Shopee'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.byTooltip('Paid'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
