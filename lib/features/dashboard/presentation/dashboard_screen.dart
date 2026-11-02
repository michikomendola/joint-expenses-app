import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/month_picker.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/transaction_type.dart';
import '../../../data/services/realtime_sync.dart';
import '../../authentication/application/auth_providers.dart';
import '../../households/application/household_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/presentation/transaction_actions.dart';
import '../../transactions/presentation/transaction_detail_sheet.dart';
import '../../transactions/presentation/transaction_form_sheet.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../application/dashboard_providers.dart';
import '../application/joint_budget_providers.dart';
import '../domain/dashboard_summary.dart';
import '../domain/home_account_view.dart';
import '../domain/joint_budget.dart';
import 'share_deficit_sheet.dart';
import 'widgets/account_view_button.dart';
import 'widgets/balance_card.dart';
import 'widgets/joint_leftover_card.dart';
import 'widgets/shared_deficit_tile.dart';
import 'widgets/spending_breakdown_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final accountView = ref.watch(homeAccountViewProvider);
    final leftover = ref.watch(jointBudgetProvider);
    final month = ref.watch(selectedMonthProvider);
    final currency = ref.watch(currencyProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () async {
            refreshHouseholdData(ref);
            await Future.wait([
              ref.read(monthTransactionsProvider(month).future),
              ref.read(monthTransactionsProvider(null).future),
              ref.read(jointBudgetSharesProvider.future),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppConstants.spaceMd,
                  AppConstants.spaceMd,
                  AppConstants.spaceMd,
                  bottomInset + 120,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    _Header(
                      greeting: AppDateUtils.greeting(),
                      name: profile?.displayName,
                      month: month,
                      onMonthChanged: (value) =>
                          ref.read(selectedMonthProvider.notifier).select(value),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),
                    summary.when(
                      loading: () => const _DashboardSkeleton(),
                      error: (error, _) => AppCard(
                        child: ErrorState(
                          error: error,
                          onRetry: () => refreshHouseholdData(ref),
                        ),
                      ),
                      data: (data) => _DashboardBody(
                        summary: data,
                        leftover: leftover.valueOrNull ?? JointBudget.empty,
                        leftoverLoading: leftover.isLoading && !leftover.hasValue,
                        currency: currency,
                        month: month,
                        userId: userId,
                        view: accountView,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.name,
    required this.month,
    required this.onMonthChanged,
  });

  final String greeting;
  final String? name;
  final YearMonth? month;
  final ValueChanged<YearMonth?> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null ? '$greeting!' : '$greeting, ${name!.split(' ').first}!',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              const AccountViewButton(),
            ],
          ),
        ),
        const SizedBox(width: AppConstants.spaceSm),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: MonthChip(
            value: month,
            allowAll: true,
            onChanged: onMonthChanged,
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.summary,
    required this.leftover,
    required this.leftoverLoading,
    required this.currency,
    required this.month,
    required this.userId,
    required this.view,
  });

  final DashboardSummary summary;
  final JointBudget leftover;
  final bool leftoverLoading;
  final String currency;
  final YearMonth? month;
  final String? userId;
  final HomeAccountView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view == HomeAccountView.joint)
          AnimatedEntrance(
            child: leftoverLoading
                ? const SkeletonCard(height: 190)
                : JointLeftoverCard(
                    budget: leftover,
                    currency: currency,
                    onShare: leftover.isOverspent
                        ? () => ShareDeficitSheet.show(context, leftover)
                        : null,
                  ),
          )
        else
          AnimatedEntrance(
            child: PersonalLeftoverCard(
              amount: leftover.personalLeftover,
              currency: currency,
              prominent: true,
            ),
          ),
        if (view == HomeAccountView.joint && leftover.lastShare != null) ...[
          const SizedBox(height: AppConstants.spaceMd),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 50),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SharedDeficitTile(
                share: leftover.lastShare!,
                currency: currency,
                onTap: () => SharedDeficitDetailSheet.show(
                  context,
                  leftover.lastShare!,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppConstants.spaceMd),
        AnimatedEntrance(
          delay: const Duration(milliseconds: 60),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                TotalsCard(
                  title: 'Income',
                  amount: summary.totalIncome,
                  currency: currency,
                  isIncome: true,
                  members: summary.memberTotals,
                  onTap: () => _openList(context, ref, TransactionType.income),
                ),
                TotalsCard(
                  title: 'Expenses',
                  amount: summary.totalExpense,
                  currency: currency,
                  isIncome: false,
                  members: summary.memberTotals,
                  onTap: () => _openList(context, ref, TransactionType.expense),
                ),
              ];
              if (constraints.maxWidth < 330) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: AppConstants.spaceMd),
                    cards[1],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(child: cards[1]),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppConstants.spaceMd),
        AnimatedEntrance(
          delay: const Duration(milliseconds: 120),
          child: SpendingBreakdownCard(
            slices: summary.expenseByCategory,
            total: summary.totalExpense,
            currency: currency,
            onAddExpense: () => TransactionFormSheet.show(
              context,
              initialType: TransactionType.expense,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spaceMd),
        AnimatedEntrance(
          delay: const Duration(milliseconds: 180),
          child: AppCard(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Recent Transactions',
                  actionLabel: summary.recent.isEmpty ? null : 'See all',
                  onAction: () => _openList(context, ref, null),
                  padding: const EdgeInsets.fromLTRB(4, 0, 0, 4),
                ),
                if (summary.recent.isEmpty)
                  Builder(
                    builder: (context) {
                      final period = month;
                      final openPeriod = period == null || period.isCurrent;
                      return EmptyState(
                        compact: true,
                        icon: Icons.receipt_long_rounded,
                        title: openPeriod
                            ? 'Nothing recorded yet'
                            : 'No transactions in ${period.label}',
                        message: openPeriod
                            ? 'Tap + to add your first income or expense.'
                            : 'Pick another month or add a transaction for this period.',
                        actionLabel: 'Add transaction',
                        onAction: () => TransactionFormSheet.show(context),
                      );
                    },
                  )
                else
                  for (final t in summary.recent)
                    TransactionTile(
                      transaction: t,
                      currency: currency,
                      showDate: true,
                      isMine: t.userId == userId,
                      onTogglePaid: t.isJoint
                          ? () async {
                              final ok = await ref
                                  .read(transactionControllerProvider.notifier)
                                  .setJointPaid(t.id, paid: !t.isJointPaid);
                              if (!context.mounted) return;
                              if (!ok) {
                                AppSnackBar.error(
                                  context,
                                  ref.read(transactionControllerProvider).error,
                                );
                              }
                            }
                          : null,
                      onEdit: () => TransactionActions.edit(
                        context,
                        t,
                        userId: userId,
                      ),
                      onDelete: () => TransactionActions.delete(
                        context,
                        ref,
                        t,
                        userId: userId,
                      ),
                      onTap: () => TransactionDetailSheet.show(context, t),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openList(BuildContext context, WidgetRef ref, TransactionType? type) {
    ref.read(transactionFilterProvider.notifier).update(
          (f) => f.copyWith(
            month: month,
            clearMonth: month == null,
            type: type,
            clearType: type == null,
            clearCategory: true,
            clearUser: true,
            query: '',
            clearJointPaid: true,
          ),
        );
    context.go(AppRoutes.transactions);
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonCard(height: 190),
        SizedBox(height: AppConstants.spaceMd),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 140)),
            SizedBox(width: AppConstants.spaceMd),
            Expanded(child: SkeletonCard(height: 140)),
          ],
        ),
        SizedBox(height: AppConstants.spaceMd),
        SkeletonCard(height: 280),
        SizedBox(height: AppConstants.spaceMd),
        AppCard(
          child: Column(
            children: [SkeletonTile(), SkeletonTile(), SkeletonTile()],
          ),
        ),
      ],
    );
  }
}
