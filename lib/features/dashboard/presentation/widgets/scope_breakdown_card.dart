import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/dashboard_summary.dart';

/// Personal vs joint spending. Joint is counted once in the household total.
class ScopeBreakdownCard extends StatelessWidget {
  const ScopeBreakdownCard({
    super.key,
    required this.summary,
    required this.currency,
  });

  final DashboardSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return AppCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by owner', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Joint expenses are household costs with no individual owner.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final member in summary.memberTotals)
            _row(
              context,
              label: '${member.displayName} personal',
              amount: member.expense,
              color: colors.expense,
            ),
          _row(context, label: 'Joint expenses', amount: summary.jointExpense, color: theme.colorScheme.primary),
          const Divider(height: 20),
          _row(
            context,
            label: 'Total household expenses',
            amount: summary.totalExpense,
            color: theme.colorScheme.onSurface,
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required Money amount,
    required Color color,
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium,
            ),
          ),
          AnimatedAmount(
            amount: amount,
            currency: currency,
            style: (emphasize ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
