import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/joint_budget.dart';

class JointLeftoverCard extends StatelessWidget {
  const JointLeftoverCard({
    super.key,
    required this.budget,
    required this.currency,
    this.onShare,
  });

  final JointBudget budget;
  final String currency;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final leftover = budget.leftover;
    final Color onCard;
    final Gradient gradient;
    final String note;

    if (budget.isOverspent) {
      onCard = colors.onExpense;
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFFC62828), colors.expense],
      );
      note = 'Overspent · share so next budget starts at 0';
    } else if (budget.isReset) {
      onCard = Colors.white;
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.balanceGradientStart, colors.balanceGradientEnd],
      );
      note = 'Ready for this month’s contributions';
    } else if (budget.isUnused) {
      onCard = const Color(0xFF3D2E08);
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF6C445), Color(0xFFE8B42E)],
      );
      note = 'Unused budget · carries over';
    } else {
      onCard = Colors.white;
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.balanceGradientStart, colors.balanceGradientEnd],
      );
      note = 'Add joint income to start the pot';
    }

    return AppCard(
      gradient: gradient,
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Joint leftover',
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
                  budget.isReset
                      ? 'Shared · ${AppDateUtils.relativeShort(budget.lastShare!.sharedAt)}'
                      : 'All time',
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
              amount: leftover,
              currency: currency,
              style: theme.textTheme.displaySmall?.copyWith(
                color: onCard,
                fontSize: 38,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: onCard.withValues(alpha: 0.9),
            ),
          ),
          if (budget.isOverspent && onShare != null) ...[
            const SizedBox(height: AppConstants.spaceMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onShare,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFC62828),
                ),
                child: const Text('Share this deficit'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PersonalLeftoverCard extends StatelessWidget {
  const PersonalLeftoverCard({
    super.key,
    required this.amount,
    required this.currency,
    this.prominent = false,
  });

  final Money amount;
  final String currency;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final amountColor = amount.isNegative
        ? colors.expense
        : amount.isPositive
            ? colors.income
            : scheme.onSurface;
    return AppCard(
      padding: EdgeInsets.all(prominent ? AppConstants.spaceLg : AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your personal leftover',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedAmount(
            amount: amount,
            currency: currency,
            style: prominent
                ? theme.textTheme.displaySmall?.copyWith(color: amountColor, fontSize: 38)
                : theme.textTheme.titleLarge?.copyWith(color: amountColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Separate from the joint pot',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
