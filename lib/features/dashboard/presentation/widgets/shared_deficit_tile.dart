import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/joint_budget_share.dart';

class SharedDeficitTile extends StatelessWidget {
  const SharedDeficitTile({
    super.key,
    required this.share,
    required this.currency,
    this.onTap,
  });

  final JointBudgetShare share;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colors.balanceGradientStart.withValues(alpha: 0.16),
              child: Icon(
                Icons.handshake_outlined,
                color: colors.balanceGradientStart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shared joint deficit',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Record · ${AppDateUtils.relativeShort(share.sharedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(share.adjustmentAmount, currency: currency),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.balanceGradientStart,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
