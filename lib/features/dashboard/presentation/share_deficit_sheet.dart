import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/system_insets.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/joint_budget_share.dart';
import '../../households/application/household_providers.dart';
import '../application/joint_budget_providers.dart';
import '../domain/joint_budget.dart';

class ShareDeficitSheet extends ConsumerWidget {
  const ShareDeficitSheet({super.key, required this.budget});

  final JointBudget budget;

  static Future<void> show(BuildContext context, JointBudget budget) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ShareDeficitSheet(budget: budget),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final currency = ref.watch(currencyProvider);
    final saving = ref.watch(jointBudgetControllerProvider).isLoading;
    final leftover = budget.leftover;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, sheetBottomPadding(context, base: 24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share this deficit', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            'Joint leftover',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(leftover, currency: currency),
            style: theme.textTheme.displaySmall?.copyWith(color: colors.expense),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            leftover.isNegative
                ? 'Mark as shared so leftover goes back to ${CurrencyFormatter.format(Money.zero, currency: currency)}. Then each of you can add a joint contribution.'
                : 'This leftover is already at or above zero.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Record only. Send the actual GCash or cash transfer outside the app.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppConstants.spaceLg),
          PrimaryButton(
            label: 'Mark as shared',
            loading: saving,
            onPressed: leftover.isNegative
                ? () async {
                    final ok = await ref
                        .read(jointBudgetControllerProvider.notifier)
                        .shareDeficit();
                    if (!context.mounted) return;
                    if (ok) {
                      HapticFeedback.lightImpact();
                      AppSnackBar.success(context, 'Joint deficit marked as shared');
                      Navigator.of(context).pop();
                    } else {
                      AppSnackBar.error(
                        context,
                        ref.read(jointBudgetControllerProvider).error,
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class SharedDeficitDetailSheet extends ConsumerWidget {
  const SharedDeficitDetailSheet({super.key, required this.share});

  final JointBudgetShare share;

  static Future<void> show(BuildContext context, JointBudgetShare share) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => SharedDeficitDetailSheet(share: share),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider);
    final saving = ref.watch(jointBudgetControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, sheetBottomPadding(context, base: 24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Shared joint deficit', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            CurrencyFormatter.format(share.adjustmentAmount, currency: currency),
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Recorded ${AppDateUtils.mediumDate(share.sharedAt)}. This is not an expense.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppConstants.spaceLg),
          OutlinedButton(
            onPressed: saving
                ? null
                : () async {
                    final ok = await ref
                        .read(jointBudgetControllerProvider.notifier)
                        .undoShare(share.id);
                    if (!context.mounted) return;
                    if (ok) {
                      AppSnackBar.success(context, 'Share undone');
                      Navigator.of(context).pop();
                    } else {
                      AppSnackBar.error(
                        context,
                        ref.read(jointBudgetControllerProvider).error,
                      );
                    }
                  },
            child: const Text('Undo share'),
          ),
        ],
      ),
    );
  }
}
