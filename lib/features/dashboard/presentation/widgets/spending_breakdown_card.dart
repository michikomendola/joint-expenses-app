import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/category_icons.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/category_icon_badge.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/dashboard_summary.dart';

/// Donut chart of expenses by category with a legend.
class SpendingBreakdownCard extends StatefulWidget {
  const SpendingBreakdownCard({
    super.key,
    required this.slices,
    required this.total,
    required this.currency,
    this.onAddExpense,
    this.maxLegendItems = 6,
  });

  final List<CategorySlice> slices;
  final Money total;
  final String currency;
  final VoidCallback? onAddExpense;
  final int maxLegendItems;

  @override
  State<SpendingBreakdownCard> createState() => _SpendingBreakdownCardState();
}

class _SpendingBreakdownCardState extends State<SpendingBreakdownCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Spending Breakdown',
            padding: EdgeInsets.fromLTRB(4, 0, 0, 4),
          ),
          if (widget.slices.isEmpty)
            EmptyState(
              compact: true,
              icon: Icons.donut_large_rounded,
              title: 'No expenses yet',
              message: 'Add an expense to see where your money goes.',
              actionLabel: widget.onAddExpense == null ? null : 'Add expense',
              onAction: widget.onAddExpense,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 420;
                final chart = _buildChart(context);
                final legend = _buildLegend(context);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 180, height: 180, child: chart),
                      const SizedBox(width: AppConstants.spaceMd),
                      Expanded(child: legend),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(height: 200, child: chart),
                    const SizedBox(height: AppConstants.spaceMd),
                    legend,
                  ],
                );
              },
            ),
          if (widget.slices.length > widget.maxLegendItems)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                '+${widget.slices.length - widget.maxLegendItems} more categories',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final theme = Theme.of(context);
    final touched = _touched != null && _touched! < widget.slices.length
        ? widget.slices[_touched!]
        : null;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 58,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      response?.touchedSection == null) {
                    _touched = null;
                    return;
                  }
                  _touched = response!.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            sections: [
              for (var i = 0; i < widget.slices.length; i++)
                PieChartSectionData(
                  value: widget.slices[i].amount.toDouble(),
                  color: CategoryColors.parse(widget.slices[i].colorHex),
                  radius: _touched == i ? 30 : 22,
                  showTitle: false,
                ),
            ],
          ),
          duration: AppConstants.animSlow,
          curve: Curves.easeOutCubic,
        ),
        // Centre label.
        AnimatedSwitcher(
          duration: AppConstants.animFast,
          child: Column(
            key: ValueKey(touched?.categoryId ?? 'total'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                touched?.name ?? 'Total',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 100,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    touched == null
                        ? CurrencyFormatter.compact(widget.total, currency: widget.currency)
                        : '${touched.percentage.toStringAsFixed(touched.percentage % 1 == 0 ? 0 : 1)}%',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = widget.slices.take(widget.maxLegendItems).toList();

    return Column(
      children: [
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _touched = _touched == i ? null : i),
              child: Row(
                children: [
                  CategoryIconBadge(
                    iconKey: visible[i].icon,
                    colorHex: visible[i].colorHex,
                    size: 32,
                    selected: _touched == i,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visible[i].name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: visible[i].percentage / 100),
                            duration: AppConstants.numberAnimation,
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => LinearProgressIndicator(
                              value: value,
                              minHeight: 5,
                              color: CategoryColors.parse(visible[i].colorHex),
                              backgroundColor: scheme.surfaceContainerHigh,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${visible[i].percentage.toStringAsFixed(visible[i].percentage % 1 == 0 ? 0 : 1)}%',
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        CurrencyFormatter.format(visible[i].amount, currency: widget.currency),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
