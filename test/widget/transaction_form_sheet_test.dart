import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/money.dart';
import 'package:joint_expenses/data/models/transaction.dart';
import 'package:joint_expenses/data/models/transaction_type.dart';
import 'package:joint_expenses/features/transactions/application/transaction_providers.dart';
import 'package:joint_expenses/features/transactions/presentation/transaction_form_sheet.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

/// Records calls instead of hitting Supabase.
class _FakeTransactionController extends TransactionController {
  final List<TransactionInput> created = [];
  final List<(String, TransactionInput)> edited = [];
  final List<String> deleted = [];

  @override
  Future<bool> create(TransactionInput input) async {
    created.add(input);
    return true;
  }

  @override
  Future<bool> edit(String id, TransactionInput input) async {
    edited.add((id, input));
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    deleted.add(id);
    return true;
  }
}

Widget _host({TransactionModel? existing}) {
  return Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          onPressed: () => TransactionFormSheet.show(context, existing: existing),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  late _FakeTransactionController fake;

  Future<void> open(WidgetTester tester, {TransactionModel? existing}) async {
    fake = _FakeTransactionController();
    await pumpApp(
      tester,
      _host(existing: existing),
      transactions: Fixtures.specExample(),
      overrides: [transactionControllerProvider.overrideWith(() => fake)],
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('TransactionFormSheet – add', () {
    testWidgets('defaults to expense, today, and the current user', (tester) async {
      await open(tester);

      expect(find.text('Add transaction'), findsOneWidget);
      expect(find.text('Save expense'), findsOneWidget);
      expect(find.text('Paid by'), findsOneWidget);
      expect(find.text('Michiko'), findsOneWidget);
      expect(find.text('Select a category'), findsOneWidget);

      // Numeric keyboard for the amount.
      final amountField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.byType(TextField),
        ),
      );
      expect(amountField.keyboardType, const TextInputType.numberWithOptions(decimal: true));
    });

    testWidgets('validates amount and category before saving', (tester) async {
      await open(tester);

      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
      expect(find.text('Choose a category'), findsWidgets);
      expect(fake.created, isEmpty);
    });

    testWidgets('switching to income relabels the form and resets the category', (tester) async {
      await open(tester);

      // Pick an expense category first.
      await tester.tap(find.text('Select a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rent'));
      await tester.pumpAndSettle();
      expect(find.text('Rent'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Save income'), findsOneWidget);
      expect(find.text('Received by'), findsOneWidget);
      expect(find.text('Select a category'), findsOneWidget);
      expect(find.text('Rent'), findsNothing);
    });

    testWidgets('saves a valid expense, closes and confirms', (tester) async {
      await open(tester);

      await tester.enterText(find.byType(TextFormField).first, '1500.50');
      await tester.tap(find.text('Select a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food & Drinks'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), 'Weekly groceries');

      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();

      expect(fake.created, hasLength(1));
      final input = fake.created.single;
      expect(input.type, TransactionType.expense);
      expect(input.amount, Money.parse('1500.50'));
      expect(input.categoryId, Fixtures.food.id);
      expect(input.description, 'Weekly groceries');
      expect(input.toJson()['amount'], '1500.50');

      // Sheet closed and snackbar shown.
      expect(find.text('Add transaction'), findsNothing);
      expect(find.textContaining('saved'), findsOneWidget);
    });

    testWidgets('category picker is searchable', (tester) async {
      await open(tester);
      await tester.tap(find.text('Select a category'));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'tran');
      await tester.pumpAndSettle();
      expect(find.text('Transportation'), findsOneWidget);
      expect(find.text('Rent'), findsNothing);
    });
  });

  group('TransactionFormSheet – edit', () {
    testWidgets('pre-fills fields and submits an update', (tester) async {
      final existing = Fixtures.specExample().firstWhere((t) => t.id == 't4');
      await open(tester, existing: existing);

      expect(find.text('Edit transaction'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Food & Drinks'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '5250');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(fake.edited, hasLength(1));
      expect(fake.edited.single.$1, 't4');
      expect(fake.edited.single.$2.amount, Money.parse('5250'));
      expect(find.text('Transaction updated'), findsOneWidget);
    });

    testWidgets('delete asks for confirmation then deletes', (tester) async {
      final existing = Fixtures.specExample().firstWhere((t) => t.id == 't4');
      await open(tester, existing: existing);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete transaction?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(fake.deleted, isEmpty);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(fake.deleted, ['t4']);
      expect(find.text('Transaction deleted'), findsOneWidget);
      expect(find.text('Edit transaction'), findsNothing);
    });
  });
}
