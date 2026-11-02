import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/feedback.dart';
import '../../../data/models/transaction.dart';
import '../application/transaction_providers.dart';
import 'transaction_form_sheet.dart';

/// Edit and delete from a swiped transaction row.
abstract final class TransactionActions {
  static void edit(
    BuildContext context,
    TransactionModel transaction, {
    required String? userId,
  }) {
    if (transaction.userId != userId) {
      AppSnackBar.error(context, _locked(transaction));
      return;
    }
    TransactionFormSheet.show(context, existing: transaction);
  }

  static Future<void> delete(
    BuildContext context,
    WidgetRef ref,
    TransactionModel transaction, {
    required String? userId,
  }) async {
    if (transaction.userId != userId) {
      AppSnackBar.error(context, _locked(transaction));
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete transaction?',
      message: 'This will permanently remove "${transaction.title}" and '
          'update the household totals.',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref.read(transactionControllerProvider.notifier).delete(transaction.id);
    if (!context.mounted) return;
    if (ok) {
      AppSnackBar.success(context, 'Transaction deleted');
    } else {
      AppSnackBar.error(context, ref.read(transactionControllerProvider).error);
    }
  }

  static String _locked(TransactionModel transaction) =>
      'Only ${transaction.userDisplayName ?? 'the person who added it'} can edit this transaction.';
}
