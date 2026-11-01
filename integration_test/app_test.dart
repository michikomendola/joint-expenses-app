// End-to-end tests against a real Supabase project.
//
// Requirements (see README → Integration tests):
//   * Migrations applied, e-mail confirmation disabled (or both users confirmed).
//   * Two confirmed test users.
//   * Run with:
//       flutter test integration_test \
//         --dart-define-from-file=env.json \
//         --dart-define-from-file=env.test.json
//     where env.test.json provides TEST_USER1_EMAIL, TEST_USER1_PASSWORD,
//     TEST_USER2_EMAIL and TEST_USER2_PASSWORD.
//
// The test is self-healing: it creates a household for user 1 and joins user 2
// through a real invite code when they are not already in the same household.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:joint_expenses/core/constants/app_env.dart';
import 'package:joint_expenses/core/utils/date_utils.dart';
import 'package:joint_expenses/features/transactions/presentation/transaction_form_sheet.dart';
import 'package:joint_expenses/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:joint_expenses/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';

const _user1Email = String.fromEnvironment('TEST_USER1_EMAIL');
const _user1Password = String.fromEnvironment('TEST_USER1_PASSWORD');
const _user2Email = String.fromEnvironment('TEST_USER2_EMAIL');
const _user2Password = String.fromEnvironment('TEST_USER2_PASSWORD');

bool get _configured =>
    AppEnv.isConfigured &&
    _user1Email.isNotEmpty &&
    _user1Password.isNotEmpty &&
    _user2Email.isNotEmpty &&
    _user2Password.isNotEmpty;

/// Pumps real frames until [finder] matches or [timeout] elapses.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder to disappear');
}

Future<void> settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Backend fixtures managed with plain SupabaseClients (not the app singleton).
class _Backend {
  late final SupabaseClient user1 =
      SupabaseClient(AppEnv.supabaseUrl, AppEnv.supabaseAnonKey);
  late final SupabaseClient user2 =
      SupabaseClient(AppEnv.supabaseUrl, AppEnv.supabaseAnonKey);

  late String householdId;
  late String expenseCategoryId;
  late String incomeCategoryId;

  Future<void> setUp() async {
    await user1.auth.signInWithPassword(email: _user1Email, password: _user1Password);
    await user2.auth.signInWithPassword(email: _user2Email, password: _user2Password);

    householdId = await _ensureHousehold();
    await _ensureMembership();

    final categories = await user1
        .from('categories')
        .select('id, type, name')
        .eq('household_id', householdId);
    expenseCategoryId =
        categories.firstWhere((c) => c['type'] == 'expense')['id'] as String;
    incomeCategoryId =
        categories.firstWhere((c) => c['type'] == 'income')['id'] as String;
  }

  Future<String> _ensureHousehold() async {
    final row = await user1
        .from('household_members')
        .select('household_id')
        .eq('user_id', user1.auth.currentUser!.id)
        .order('joined_at')
        .limit(1)
        .maybeSingle();
    if (row != null) return row['household_id'] as String;
    final created = await user1.rpc<Map<String, dynamic>>(
      'create_household',
      params: {'p_name': 'Integration Test Home', 'p_currency': 'PHP'},
    );
    return created['id'] as String;
  }

  Future<void> _ensureMembership() async {
    final existing = await user2
        .from('household_members')
        .select('id')
        .eq('household_id', householdId)
        .eq('user_id', user2.auth.currentUser!.id)
        .maybeSingle();
    if (existing != null) return;
    final invite = await user1.rpc<List<dynamic>>(
      'create_household_invite',
      params: {'p_household_id': householdId},
    );
    final code = (invite.first as Map<String, dynamic>)['code'] as String;
    await user2.rpc<Map<String, dynamic>>(
      'join_household_with_invite',
      params: {'p_code': code},
    );
  }

  Future<void> cleanUp(List<String> descriptions) async {
    for (final client in [user1, user2]) {
      final uid = client.auth.currentUser?.id;
      if (uid == null) continue;
      for (final d in descriptions) {
        await client.from('transactions').delete().eq('user_id', uid).eq('description', d);
      }
    }
    await user1.auth.signOut();
    await user2.auth.signOut();
    await user1.dispose();
    await user2.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final incomeDesc = 'IT income $stamp';
  final expenseDesc = 'IT expense $stamp';
  final syncDesc = 'IT sync $stamp';
  final backend = _Backend();

  setUpAll(() async {
    if (!_configured) return;
    await backend.setUp();
  });

  tearDownAll(() async {
    if (!_configured) return;
    await backend.cleanUp([incomeDesc, expenseDesc, syncDesc]);
  });

  testWidgets('end-to-end: auth, add, edit, delete and household sync',
      (tester) async {
    if (!_configured) {
      markTestSkipped(
        'Supabase and TEST_USER* dart-defines are required for integration tests.',
      );
      return;
    }

    // ------------------------------------------------------------ launch
    await app.main();
    await settle(tester);

    // Start signed-out so the login flow is exercised.
    final appClient = Supabase.instance.client;
    if (appClient.auth.currentSession != null) {
      await appClient.auth.signOut();
    }
    await pumpUntil(tester, find.text('Welcome back'));

    // -------------------------------------------------------- authentication
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), _user1Email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), _user1Password);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await pumpUntil(tester, find.text('Available Balance'));
    expect(appClient.auth.currentUser?.email, _user1Email);

    final sheet = find.byType(TransactionFormSheet);
    Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);

    // ----------------------------------------------------------- add income
    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntil(tester, inSheet(find.text('Add transaction')));
    await tester.tap(inSheet(find.text('Income')));
    await settle(tester);
    await tester.enterText(inSheet(find.byType(TextFormField)).first, '12345.67');
    await tester.tap(inSheet(find.text('Select a category')));
    await pumpUntil(tester, find.text('Salary'));
    await tester.tap(find.text('Salary'));
    await settle(tester);
    await tester.enterText(inSheet(find.byType(TextFormField)).at(1), incomeDesc);
    await tester.tap(inSheet(find.text('Save income')));
    await pumpUntil(tester, find.textContaining('Income of ₱12,345.67 saved'));
    await pumpUntil(tester, find.text(incomeDesc));

    // ---------------------------------------------------------- add expense
    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntil(tester, inSheet(find.text('Add transaction')));
    await tester.enterText(inSheet(find.byType(TextFormField)).first, '1500');
    await tester.tap(inSheet(find.text('Select a category')));
    await pumpUntil(tester, find.text('Groceries'));
    await tester.tap(find.text('Groceries'));
    await settle(tester);
    await tester.enterText(inSheet(find.byType(TextFormField)).at(1), expenseDesc);
    await tester.tap(inSheet(find.text('Save expense')));
    await pumpUntil(tester, find.textContaining('Expense of ₱1,500.00 saved'));
    await pumpUntil(tester, find.text(expenseDesc));
    expect(find.text('- ₱1,500.00'), findsWidgets);

    // ------------------------------------------------------ edit transaction
    await tester.tap(find.text(expenseDesc));
    await pumpUntil(tester, find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await pumpUntil(tester, inSheet(find.text('Edit transaction')));
    await tester.enterText(inSheet(find.byType(TextFormField)).first, '1750.25');
    await tester.tap(inSheet(find.text('Save changes')));
    await pumpUntil(tester, find.text('Transaction updated'));
    await pumpUntil(tester, find.text('- ₱1,750.25'));
    expect(find.text('- ₱1,500.00'), findsNothing);

    // ---------------------------------------------------- delete transaction
    await tester.tap(find.text(expenseDesc));
    await pumpUntil(tester, find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await pumpUntil(tester, find.text('Delete transaction?'));
    // The confirm dialog's action button is the last "Delete" in the tree.
    await tester.tap(find.text('Delete').last);
    await pumpUntil(tester, find.text('Transaction deleted'));
    await pumpUntilGone(tester, find.text(expenseDesc));

    // ------------------------------------------------ household synchronization
    // User 2 adds a transaction from another device; user 1's dashboard must
    // update without any manual refresh (Supabase Realtime).
    final tilesBefore = find.byType(TransactionTile).evaluate().length;
    await backend.user2.from('transactions').insert({
      'household_id': backend.householdId,
      'user_id': backend.user2.auth.currentUser!.id,
      'type': 'expense',
      'amount': '999.99',
      'category_id': backend.expenseCategoryId,
      'description': syncDesc,
      'transaction_date': AppDateUtils.toIsoDate(DateTime.now()),
    });
    await pumpUntil(tester, find.text(syncDesc), timeout: const Duration(seconds: 30));
    expect(find.text('- ₱999.99'), findsWidgets);
    expect(find.byType(TransactionTile).evaluate().length, greaterThanOrEqualTo(tilesBefore));

    // A partner's transaction is read-only for user 1.
    await tester.tap(find.text(syncDesc));
    await pumpUntil(tester, find.textContaining('can edit this transaction'));
    expect(find.text('Edit'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    // User 2 deletes it → it must vanish for user 1 as well.
    await backend.user2
        .from('transactions')
        .delete()
        .eq('user_id', backend.user2.auth.currentUser!.id)
        .eq('description', syncDesc);
    await pumpUntilGone(tester, find.text(syncDesc), timeout: const Duration(seconds: 30));

    // ------------------------------------------------------------- sign out
    await appClient.auth.signOut();
    await pumpUntil(tester, find.text('Welcome back'));
  });
}
