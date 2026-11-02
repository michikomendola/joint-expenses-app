import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/category_icon_badge.dart';
import '../../../../data/models/transaction.dart';

/// One transaction row: category icon, title, meta line and signed amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currency,
    this.onTap,
    this.showDate = false,
    this.isMine = false,
    this.onTogglePaid,
    this.onEdit,
    this.onDelete,
  });

  final TransactionModel transaction;
  final String currency;
  final VoidCallback? onTap;

  /// Show the date in the meta line (used on the dashboard where rows are
  /// not grouped by day).
  final bool showDate;
  final bool isMine;

  /// Joint expenses swipe left to reveal Paid or Unpaid.
  final VoidCallback? onTogglePaid;

  /// Swipe left to edit. Shown for every transaction when set.
  final VoidCallback? onEdit;

  /// Swipe left to delete. Shown for every transaction when set.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final t = transaction;
    final credit = t.isIncome ? !t.amount.isNegative : t.amount.isNegative;
    final amountColor = credit ? colors.income : colors.expense;

    final actor = t.isJointScope
        ? 'Joint'
        : (isMine && (t.expenseOwnerId == t.userId || t.assignedUserId == null)
            ? 'You'
            : (t.assignedDisplayName ?? t.userDisplayName ?? 'Member'));
    final metaParts = <String>[
      if (t.description?.trim().isNotEmpty == true) t.categoryName,
      t.expenseScope.label,
      if (t.isExpense) t.paymentMethod.label,
      if (!t.isJointScope) '${t.type.actorLabel} $actor',
      if (t.isJointScope) (t.isIncome ? 'Joint pot' : 'Household'),
      if (showDate) AppDateUtils.relativeShort(t.transactionDate),
    ];

    final row = Semantics(
      button: onTap != null,
      label: '${t.title}, ${t.type.label}, '
          '${CurrencyFormatter.format(t.amount, currency: currency)}, '
          '${t.type.actorLabel} $actor, ${AppDateUtils.shortDate(t.transactionDate)}'
          '${t.isJointPaid ? ', paid' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              CategoryIconBadge(
                iconKey: t.category?.icon,
                colorHex: t.category?.color,
                paid: t.isJointPaid,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metaParts.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                CurrencyFormatter.formatSigned(
                  t.amount,
                  currency: currency,
                  isIncome: t.isIncome,
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final actions = <_SwipeAction>[
      if (onEdit != null)
        _SwipeAction(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          background: const Color(0xFF3949AB),
          foreground: Colors.white,
          onTap: onEdit!,
        ),
      if (onDelete != null)
        _SwipeAction(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete',
          background: colors.expense,
          foreground: colors.onExpense,
          onTap: onDelete!,
        ),
      if (t.isJoint && onTogglePaid != null)
        _SwipeAction(
          icon: t.isJointPaid ? Icons.close_rounded : Icons.check_rounded,
          tooltip: t.isJointPaid ? 'Unpaid' : 'Paid',
          background: t.isJointPaid ? colors.expense : colors.income,
          foreground: t.isJointPaid ? colors.onExpense : colors.onIncome,
          onTap: onTogglePaid!,
        ),
    ];
    if (actions.isEmpty) return row;
    return _TransactionSwipe(
      actions: actions,
      settleKey: t.isJointPaid,
      child: row,
    );
  }
}

class _SwipeAction {
  const _SwipeAction({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
}

/// Reveals icon actions when a transaction is swiped left.
class _TransactionSwipe extends StatefulWidget {
  const _TransactionSwipe({
    required this.actions,
    required this.settleKey,
    required this.child,
  });

  final List<_SwipeAction> actions;
  final Object? settleKey;
  final Widget child;

  @override
  State<_TransactionSwipe> createState() => _TransactionSwipeState();
}

class _TransactionSwipeState extends State<_TransactionSwipe> {
  static const double _actionWidth = 56;
  double _offset = 0;

  double get _reveal => _actionWidth * widget.actions.length;

  @override
  void didUpdateWidget(covariant _TransactionSwipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settleKey != widget.settleKey) _offset = 0;
  }

  void _settle(double velocity) {
    final flingOpen = velocity < -400;
    final flingClose = velocity > 400;
    setState(() {
      if (flingClose) {
        _offset = 0;
      } else if (flingOpen || _offset < -_reveal / 2) {
        _offset = -_reveal;
      } else {
        _offset = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerLowest;

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in widget.actions)
                    SizedBox(
                      width: _actionWidth,
                      child: Material(
                        color: action.background,
                        child: InkWell(
                          onTap: () {
                            setState(() => _offset = 0);
                            action.onTap();
                          },
                          child: Tooltip(
                            message: action.tooltip,
                            child: Center(
                              child: Icon(action.icon, color: action.foreground, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _offset = (_offset + details.delta.dx).clamp(-_reveal, 0);
              });
            },
            onHorizontalDragEnd: (details) {
              _settle(details.primaryVelocity ?? 0);
            },
            child: Transform.translate(
              offset: Offset(_offset, 0),
              child: Material(color: surface, child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}
