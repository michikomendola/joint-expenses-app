import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/category_icon_badge.dart';
import '../../../core/widgets/month_picker.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/joint_budget_share.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/transaction_type.dart';
import '../../authentication/application/auth_providers.dart';
import '../../categories/application/category_providers.dart';
import '../../categories/presentation/category_picker_sheet.dart';
import '../../dashboard/application/account_view_provider.dart';
import '../../dashboard/application/joint_budget_providers.dart';
import '../../dashboard/domain/home_account_view.dart';
import '../../dashboard/presentation/share_deficit_sheet.dart';
import '../../dashboard/presentation/widgets/account_view_button.dart';
import '../../dashboard/presentation/widgets/shared_deficit_tile.dart';
import '../../households/application/household_providers.dart';
import '../application/transaction_providers.dart';
import '../domain/transaction_filter.dart';
import 'transaction_actions.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_form_sheet.dart';
import 'widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(transactionFilterProvider).query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _search.clear();
        ref.read(transactionFilterProvider.notifier).setQuery('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(transactionFilterProvider);
    final view = ref.watch(homeAccountViewProvider);
    final grouped = ref.watch(groupedTransactionsProvider);
    final shares = ref.watch(jointBudgetSharesProvider).value ?? const [];
    final currency = ref.watch(currencyProvider);
    final userId = ref.watch(currentUserIdProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search description, category, name…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: theme.textTheme.bodyLarge,
                onChanged: ref.read(transactionFilterProvider.notifier).setQuery,
              )
            : AccountViewButton(style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Import credit card statement',
            onPressed: () => context.push(AppRoutes.statementImport),
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          IconButton(
            tooltip: filter.sort == TransactionSort.newestFirst
                ? 'Newest first'
                : 'Oldest first',
            onPressed: ref.read(transactionFilterProvider.notifier).toggleSort,
            icon: Icon(
              filter.sort == TransactionSort.newestFirst
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(filter: filter),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: () => ref.refresh(monthTransactionsProvider(filter.month).future),
              child: grouped.when(
                loading: () => ListView(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  children: const [
                    SkeletonBox(width: 80, height: 14),
                    SizedBox(height: 8),
                    AppCard(child: Column(children: [SkeletonTile(), SkeletonTile(), SkeletonTile()])),
                    SizedBox(height: 20),
                    SkeletonBox(width: 110, height: 14),
                    SizedBox(height: 8),
                    AppCard(child: Column(children: [SkeletonTile(), SkeletonTile()])),
                  ],
                ),
                error: (error, _) => ListView(
                  children: [
                    ErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(monthTransactionsProvider),
                    ),
                  ],
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 40),
                        EmptyState(
                          icon: filter.hasActiveFilters
                              ? Icons.filter_alt_off_rounded
                              : Icons.receipt_long_rounded,
                          title: filter.hasActiveFilters
                              ? 'No matching transactions'
                              : (view == HomeAccountView.joint
                                  ? 'No joint transactions yet'
                                  : 'No personal transactions yet'),
                          message: filter.hasActiveFilters
                              ? 'Try clearing a filter or choosing another month.'
                              : 'Tap + to record your first income or expense.',
                          actionLabel: filter.hasActiveFilters ? null : 'Add transaction',
                          onAction: filter.hasActiveFilters
                              ? null
                              : () => TransactionFormSheet.show(context),
                        ),
                        if (filter.hasActiveFilters)
                          Center(
                            child: TextButton(
                              onPressed: () {
                                _search.clear();
                                ref.read(transactionFilterProvider.notifier).clear();
                              },
                              child: const Text('Clear filters'),
                            ),
                          ),
                      ],
                    );
                  }

                  final totals = _PeriodTotals.from(groups);
                  final visibleShares = view == HomeAccountView.joint && !filter.hasActiveFilters
                      ? shares.where((s) {
                          return filter.month == null ||
                              filter.month!.contains(s.sharedAt);
                        }).toList()
                      : <JointBudgetShare>[];
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      AppConstants.spaceMd, 4, AppConstants.spaceMd, bottomInset + 120,
                    ),
                    itemCount: groups.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          children: [
                            _TotalsStrip(totals: totals, currency: currency),
                            for (final share in visibleShares)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppConstants.spaceMd),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: SharedDeficitTile(
                                    share: share,
                                    currency: currency,
                                    onTap: () => SharedDeficitDetailSheet.show(
                                      context,
                                      share,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }
                      final group = groups[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppConstants.spaceMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      group.label().toUpperCase(),
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _netLabel(group, currency),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Column(
                                children: [
                                  for (var i = 0; i < group.items.length; i++) ...[
                                    TransactionTile(
                                      transaction: group.items[i],
                                      currency: currency,
                                      isMine: group.items[i].userId == userId,
                                      onTogglePaid: group.items[i].isJoint
                                          ? () => _togglePaid(ref, group.items[i])
                                          : null,
                                      onEdit: () => TransactionActions.edit(
                                        context,
                                        group.items[i],
                                        userId: userId,
                                      ),
                                      onDelete: () => TransactionActions.delete(
                                        context,
                                        ref,
                                        group.items[i],
                                        userId: userId,
                                      ),
                                      onTap: () => TransactionDetailSheet.show(
                                        context,
                                        group.items[i],
                                      ),
                                    ),
                                    if (i < group.items.length - 1)
                                      Divider(indent: 60, color: scheme.outlineVariant),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePaid(WidgetRef ref, TransactionModel transaction) async {
    final ok = await ref.read(transactionControllerProvider.notifier).setJointPaid(
          transaction.id,
          paid: !transaction.isJointPaid,
        );
    if (!mounted) return;
    if (!ok) {
      AppSnackBar.error(context, ref.read(transactionControllerProvider).error);
    }
  }

  String _netLabel(TransactionGroup group, String currency) {
    final net = Money.sum(group.items.map((t) => t.signedAmount));
    final prefix = net.isNegative ? '− ' : '+ ';
    return '$prefix${CurrencyFormatter.format(net.abs, currency: currency)}';
  }
}

class _PeriodTotals {
  const _PeriodTotals(this.income, this.expense);

  factory _PeriodTotals.from(List<TransactionGroup> groups) {
    var income = Money.zero;
    var expense = Money.zero;
    for (final g in groups) {
      for (final t in g.items) {
        if (t.isIncome) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
    }
    return _PeriodTotals(income, expense);
  }

  final Money income;
  final Money expense;
}

class _TotalsStrip extends StatelessWidget {
  const _TotalsStrip({required this.totals, required this.currency});

  final _PeriodTotals totals;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceMd, left: 4, right: 4),
      child: Row(
        children: [
          _TotalChip(
            label: 'Income',
            value: CurrencyFormatter.compact(totals.income, currency: currency),
            color: colors.income,
            background: colors.incomeContainer,
          ),
          const SizedBox(width: 8),
          _TotalChip(
            label: 'Expenses',
            value: CurrencyFormatter.compact(totals.expense, currency: currency),
            color: colors.expense,
            background: colors.expenseContainer,
          ),
          const SizedBox(width: 8),
          _TotalChip(
            label: 'Net',
            value: CurrencyFormatter.compact(totals.income - totals.expense, currency: currency),
            color: theme.colorScheme.onSurface,
            background: theme.colorScheme.surfaceContainer,
          ),
        ],
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal row of filter chips (type, category, member, month).
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});

  final TransactionFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(transactionFilterProvider.notifier);
    final categories = ref.watch(categoryMapProvider);
    final memberNames = ref.watch(memberNamesProvider);
    final members = ref.watch(householdMembersProvider).value ?? const [];
    final scheme = Theme.of(context).colorScheme;

    final view = ref.watch(homeAccountViewProvider);
    final selectedCategory = filter.categoryId == null ? null : categories[filter.categoryId!];

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd, vertical: 8),
        children: [
          MonthChip(
            value: filter.month,
            allowAll: true,
            compact: true,
            onChanged: notifier.setMonth,
          ),
          const SizedBox(width: 8),
          _TypeFilterChips(
            value: filter.type,
            onChanged: (type) => notifier.update(
              (f) => type == null ? f.copyWith(clearType: true) : f.copyWith(type: type),
            ),
          ),
          if (view == HomeAccountView.joint) ...[
            const SizedBox(width: 8),
            _PaidFilterChips(
              value: filter.jointPaid,
              onChanged: (value) => notifier.update(
                (f) => value == JointPaidFilter.all
                    ? f.copyWith(clearJointPaid: true)
                    : f.copyWith(jointPaid: value),
              ),
            ),
          ],
          const SizedBox(width: 8),
          FilterChip(
            selected: selectedCategory != null,
            avatar: selectedCategory == null
                ? const Icon(Icons.category_outlined, size: 18)
                : CategoryIconBadge(
                    iconKey: selectedCategory.icon,
                    colorHex: selectedCategory.color,
                    size: 22,
                  ),
            label: Text(selectedCategory?.name ?? 'Category'),
            onSelected: (_) async {
              if (selectedCategory != null) {
                notifier.update((f) => f.copyWith(clearCategory: true));
                return;
              }
              final type = filter.type ?? TransactionType.expense;
              final picked = await CategoryPickerSheet.show(
                context,
                type: type,
                title: 'Filter by category',
              );
              if (picked != null) {
                notifier.update((f) => f.copyWith(categoryId: picked.id, type: picked.type));
              }
            },
            onDeleted: selectedCategory == null
                ? null
                : () => notifier.update((f) => f.copyWith(clearCategory: true)),
            deleteIcon: const Icon(Icons.close_rounded, size: 16),
          ),
          const SizedBox(width: 8),
          if (view == HomeAccountView.joint && members.length > 1)
            PopupMenuButton<String?>(
              tooltip: 'Filter by member',
              onSelected: (value) => notifier.update(
                (f) => value == null ? f.copyWith(clearUser: true) : f.copyWith(userId: value),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem<String?>(value: null, child: Text('Everyone')),
                for (final m in members)
                  PopupMenuItem<String?>(value: m.userId, child: Text(m.displayName)),
              ],
              child: Chip(
                avatar: Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: filter.userId != null ? scheme.onPrimaryContainer : null,
                ),
                label: Text(filter.userId == null ? 'Everyone' : (memberNames[filter.userId] ?? 'Member')),
                backgroundColor: filter.userId != null ? scheme.primaryContainer : null,
              ),
            ),
          if (filter.hasActiveFilters) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear'),
              onPressed: notifier.clear,
            ),
          ],
        ],
      ),
    );
  }
}

class _PaidFilterChips extends StatelessWidget {
  const _PaidFilterChips({required this.value, required this.onChanged});

  final JointPaidFilter value;
  final ValueChanged<JointPaidFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        ChoiceChip(
          label: const Text('Unpaid'),
          selected: value == JointPaidFilter.unpaid,
          onSelected: (_) => onChanged(
            value == JointPaidFilter.unpaid ? JointPaidFilter.all : JointPaidFilter.unpaid,
          ),
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('Paid'),
          selected: value == JointPaidFilter.paid,
          selectedColor: colors.incomeContainer,
          onSelected: (_) => onChanged(
            value == JointPaidFilter.paid ? JointPaidFilter.all : JointPaidFilter.paid,
          ),
        ),
      ],
    );
  }
}

class _TypeFilterChips extends StatelessWidget {
  const _TypeFilterChips({required this.value, required this.onChanged});

  final TransactionType? value;
  final ValueChanged<TransactionType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: value == null,
          onSelected: (_) => onChanged(null),
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('Income'),
          selected: value == TransactionType.income,
          selectedColor: colors.incomeContainer,
          onSelected: (_) => onChanged(TransactionType.income),
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('Expenses'),
          selected: value == TransactionType.expense,
          selectedColor: colors.expenseContainer,
          onSelected: (_) => onChanged(TransactionType.expense),
        ),
      ],
    );
  }
}
