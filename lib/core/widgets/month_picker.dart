import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../utils/date_utils.dart';

/// Compact chip that shows the selected month and opens the picker.
class MonthChip extends StatelessWidget {
  const MonthChip({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowAll = false,
    this.compact = false,
  });

  /// `null` means "all time" (only when [allowAll] is true).
  final YearMonth? value;
  final ValueChanged<YearMonth?> onChanged;
  final bool allowAll;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = value == null
        ? 'All time'
        : (compact ? value!.shortLabel : value!.label);
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final picked = await MonthPickerSheet.show(
            context,
            initial: value,
            allowAll: allowAll,
          );
          if (picked != null) {
            onChanged(picked.value);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper so the sheet can return `null` as an explicit "all time" choice.
class MonthSelection {
  const MonthSelection(this.value);
  final YearMonth? value;
}

/// Bottom sheet with a year switcher and a 12-month grid.
class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({
    super.key,
    required this.initial,
    this.allowAll = false,
  });

  final YearMonth? initial;
  final bool allowAll;

  static Future<MonthSelection?> show(
    BuildContext context, {
    required YearMonth? initial,
    bool allowAll = false,
  }) {
    return showModalBottomSheet<MonthSelection>(
      context: context,
      useSafeArea: true,
      builder: (_) => MonthPickerSheet(initial: initial, allowAll: allowAll),
    );
  }

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late int _year = (widget.initial ?? YearMonth.now()).year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = YearMonth.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _year--),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous year',
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppConstants.animFast,
                  child: Text(
                    '$_year',
                    key: ValueKey(_year),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                onPressed: _year < now.year + 1 ? () => setState(() => _year++) : null,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next year',
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = YearMonth(_year, index + 1);
              final selected = month == widget.initial;
              final isFuture = month.compareTo(now) > 0;
              final isNow = month == now;
              return Material(
                color: selected ? scheme.primary : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  onTap: isFuture
                      ? null
                      : () => Navigator.of(context).pop(MonthSelection(month)),
                  child: Center(
                    child: Text(
                      DateFormat.MMM().format(month.start),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected
                            ? scheme.onPrimary
                            : isFuture
                                ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                                : isNow
                                    ? scheme.primary
                                    : scheme.onSurface,
                        fontWeight: isNow || selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              if (widget.allowAll)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const MonthSelection(null)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                    child: const Text('All time'),
                  ),
                ),
              if (widget.allowAll) const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(MonthSelection(now)),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  child: const Text('This month'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
