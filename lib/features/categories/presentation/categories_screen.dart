import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/category_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/animated_amount.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/category_icon_badge.dart';
import '../../../core/widgets/month_picker.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction_type.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../dashboard/domain/dashboard_summary.dart';
import '../../households/application/household_providers.dart';
import '../application/category_providers.dart';
import 'category_form_sheet.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  TransactionType _type = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final categories = ref.watch(categoriesByTypeProvider(_type));
    final summary = ref.watch(dashboardSummaryProvider);
    final month = ref.watch(selectedMonthProvider);
    final currency = ref.watch(currencyProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final slices = summary.value == null
        ? const <CategorySlice>[]
        : (_type.isExpense ? summary.value!.expenseByCategory : summary.value!.incomeByCategory);
    final sliceById = {for (final s in slices) s.categoryId: s};
    final periodTotal = Money.sum(slices.map((s) => s.amount));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'New category',
            onPressed: () => CategoryFormSheet.show(context, type: _type),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spaceMd, 4, AppConstants.spaceMd, AppConstants.spaceSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Expenses'),
                        icon: Icon(Icons.arrow_upward_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Income'),
                        icon: Icon(Icons.arrow_downward_rounded, size: 16),
                      ),
                    ],
                    selected: {_type},
                    showSelectedIcon: false,
                    onSelectionChanged: (set) => setState(() => _type = set.first),
                  ),
                ),
                const SizedBox(width: 8),
                MonthChip(
                  value: month,
                  compact: true,
                  onChanged: (value) {
                    if (value != null) ref.read(selectedMonthProvider.notifier).select(value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: categories.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppConstants.spaceMd),
                children: const [
                  AppCard(
                    child: Column(
                      children: [SkeletonTile(), SkeletonTile(), SkeletonTile(), SkeletonTile()],
                    ),
                  ),
                ],
              ),
              error: (error, _) => ErrorState(
                error: error,
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.category_outlined,
                    title: 'No ${_type.label.toLowerCase()} categories',
                    message: 'Create one to start organising your ${_type.label.toLowerCase()}s.',
                    actionLabel: 'New category',
                    onAction: () => CategoryFormSheet.show(context, type: _type),
                  );
                }

                // Sort: used categories by amount desc, then unused alphabetically.
                final sorted = [...list]..sort((a, b) {
                    final sa = sliceById[a.id]?.amount ?? Money.zero;
                    final sb = sliceById[b.id]?.amount ?? Money.zero;
                    final cmp = sb.compareTo(sa);
                    return cmp != 0 ? cmp : a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });
                final maxAmount = sorted.isEmpty
                    ? Money.zero
                    : (sliceById[sorted.first.id]?.amount ?? Money.zero);

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(
                    AppConstants.spaceMd, 4, AppConstants.spaceMd, bottomInset + 120,
                  ),
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(AppConstants.spaceMd),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total ${_type.label.toLowerCase()} · ${month.shortLabel}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AnimatedAmount(
                                  amount: periodTotal,
                                  currency: currency,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: _type.isExpense ? colors.expense : colors.income,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${list.length} ${list.length == 1 ? 'category' : 'categories'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < sorted.length; i++) ...[
                            _CategoryRow(
                              category: sorted[i],
                              slice: sliceById[sorted[i].id],
                              maxAmount: maxAmount,
                              currency: currency,
                              onTap: () => CategoryFormSheet.show(
                                context,
                                type: _type,
                                existing: sorted[i],
                              ),
                            ),
                            if (i < sorted.length - 1)
                              Divider(indent: 60, color: scheme.outlineVariant),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.slice,
    required this.maxAmount,
    required this.currency,
    required this.onTap,
  });

  final CategoryModel category;
  final CategorySlice? slice;
  final Money maxAmount;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final amount = slice?.amount ?? Money.zero;
    final ratio = maxAmount.isZero ? 0.0 : amount.ratioOf(maxAmount);
    final color = CategoryColors.parse(category.color);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            CategoryIconBadge(iconKey: category.icon, colorHex: category.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.name,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.format(amount, currency: currency),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: amount.isZero ? scheme.onSurfaceVariant : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: ratio),
                            duration: AppConstants.numberAnimation,
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => LinearProgressIndicator(
                              value: value,
                              minHeight: 5,
                              color: color,
                              backgroundColor: scheme.surfaceContainerHigh,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 84,
                        child: Text(
                          slice == null
                              ? 'No transactions'
                              : '${slice!.count} ${slice!.count == 1 ? 'txn' : 'txns'} · '
                                  '${slice!.percentage.toStringAsFixed(slice!.percentage % 1 == 0 ? 0 : 1)}%',
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
