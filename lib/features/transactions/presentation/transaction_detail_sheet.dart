import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/category_icon_badge.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/models/transaction.dart';
import '../../authentication/application/auth_providers.dart';
import '../../households/application/household_providers.dart';
import '../application/transaction_providers.dart';
import 'transaction_form_sheet.dart';

/// Read-only details with Edit / Delete for the creator.
class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({super.key, required this.transaction});

  final TransactionModel transaction;

  static Future<void> show(BuildContext context, TransactionModel transaction) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => TransactionDetailSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final currency = ref.watch(currencyProvider);
    final isMine = ref.watch(currentUserIdProvider) == transaction.userId;
    final t = transaction;
    final accent = t.isIncome ? colors.income : colors.expense;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CategoryIconBadge(iconKey: t.category?.icon, colorHex: t.category?.color, size: 52),
              const SizedBox(width: AppConstants.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, style: theme.textTheme.titleMedium, maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${t.type.label} · ${t.categoryName}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceLg),
          Text(
            CurrencyFormatter.formatSigned(t.amount, currency: currency, isIncome: t.isIncome),
            style: theme.textTheme.displaySmall?.copyWith(color: accent, fontSize: 34),
          ),
          const SizedBox(height: AppConstants.spaceLg),
          _DetailRow(
            icon: Icons.event_rounded,
            label: 'Date',
            value: AppDateUtils.mediumDate(t.transactionDate),
          ),
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: t.type.actorLabel,
            value: isMine ? 'You (${t.userDisplayName ?? 'me'})' : (t.userDisplayName ?? 'Member'),
          ),
          if (t.createdAt != null)
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Added',
              value: AppDateUtils.mediumDate(t.createdAt!),
            ),
          const SizedBox(height: AppConstants.spaceLg),
          if (isMine)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await ConfirmDialog.show(
                        context,
                        title: 'Delete transaction?',
                        message: 'This will permanently remove "${t.title}" and '
                            'update the household totals.',
                      );
                      if (!confirmed || !context.mounted) return;
                      final ok = await ref
                          .read(transactionControllerProvider.notifier)
                          .delete(t.id);
                      if (!context.mounted) return;
                      if (ok) {
                        AppSnackBar.success(context, 'Transaction deleted');
                        Navigator.of(context).pop();
                      } else {
                        AppSnackBar.error(
                          context,
                          ref.read(transactionControllerProvider).error,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      TransactionFormSheet.show(context, existing: t);
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only ${t.userDisplayName ?? 'the person who added it'} can edit this transaction.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
