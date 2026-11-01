import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/category_icon_badge.dart';
import '../../../../data/models/transaction.dart';

/// One transaction row: category icon, title, meta line and signed amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currency,
    this.onTap,
    this.showDate = false,
    this.isMine = false,
  });

  final TransactionModel transaction;
  final String currency;
  final VoidCallback? onTap;

  /// Show the date in the meta line (used on the dashboard where rows are
  /// not grouped by day).
  final bool showDate;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final t = transaction;
    final amountColor = t.isIncome ? colors.income : colors.expense;

    final actor = isMine ? 'You' : (t.userDisplayName ?? 'Member');
    final metaParts = <String>[
      if (t.description?.trim().isNotEmpty == true) t.categoryName,
      '${t.type.actorLabel} $actor',
      if (showDate) AppDateUtils.relativeShort(t.transactionDate),
    ];

    return Semantics(
      button: onTap != null,
      label: '${t.title}, ${t.type.label}, '
          '${CurrencyFormatter.format(t.amount, currency: currency)}, '
          '${t.type.actorLabel} $actor, ${AppDateUtils.shortDate(t.transactionDate)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              CategoryIconBadge(
                iconKey: t.category?.icon,
                colorHex: t.category?.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metaParts.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                CurrencyFormatter.formatSigned(
                  t.amount,
                  currency: currency,
                  isIncome: t.isIncome,
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
