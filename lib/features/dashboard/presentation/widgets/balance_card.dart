import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/dashboard_summary.dart';

/// Hero card with the remaining balance and a spent-ratio bar.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.summary,
    required this.currency,
    required this.periodLabel,
  });

  final DashboardSummary summary;
  final String currency;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    const onCard = Colors.white;
    final isNegative = summary.balance.isNegative;

    return AppCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.balanceGradientStart, colors.balanceGradientEnd],
      ),
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available Balance',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: onCard.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: onCard.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  periodLabel,
                  style: theme.textTheme.labelMedium?.copyWith(color: onCard),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedAmount(
              amount: summary.balance,
              currency: currency,
              style: theme.textTheme.displaySmall?.copyWith(
                color: onCard,
                fontSize: 38,
              ),
            ),
          ),
          if (isNegative) ...[
            const SizedBox(height: 4),
            Text(
              'Spending exceeds income this period',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onCard.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spaceLg),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: summary.spentRatio),
              duration: AppConstants.numberAnimation,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: onCard.withValues(alpha: 0.22),
                color: isNegative ? const Color(0xFFFFB4AB) : onCard,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.totalIncome.isZero
                      ? 'No income recorded yet'
                      : '${(summary.spentRatio * 100).round()}% of income spent',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onCard.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Text(
                '${summary.transactionCount} '
                '${summary.transactionCount == 1 ? 'transaction' : 'transactions'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onCard.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact income / expense summary card with per-member breakdown.
class TotalsCard extends StatelessWidget {
  const TotalsCard({
    super.key,
    required this.title,
    required this.amount,
    required this.currency,
    required this.isIncome,
    required this.members,
    this.onTap,
  });

  final String title;
  final Money amount;
  final String currency;
  final bool isIncome;
  final List<MemberTotal> members;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final accent = isIncome ? colors.income : colors.expense;
    final container = isIncome ? colors.incomeContainer : colors.expenseContainer;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: container, shape: BoxShape.circle),
                child: Icon(
                  isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedAmount(
              amount: amount,
              currency: currency,
              style: theme.textTheme.titleLarge?.copyWith(color: accent, fontSize: 20),
            ),
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      CurrencyFormatter.compact(
                        isIncome ? m.income : m.expense,
                        currency: currency,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
