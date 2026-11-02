import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/system_insets.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/category_icon_badge.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/category.dart';
import '../../../data/models/expense_scope.dart';
import '../../../data/models/payment_method.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/transaction_type.dart';
import '../../authentication/application/auth_providers.dart';
import '../../categories/application/category_providers.dart';
import '../../categories/presentation/category_picker_sheet.dart';
import '../../households/application/household_providers.dart';
import '../application/transaction_providers.dart';

/// Bottom sheet for adding or editing a transaction.
class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({
    super.key,
    this.existing,
    this.initialType = TransactionType.expense,
  });

  /// When provided the sheet edits this transaction.
  final TransactionModel? existing;
  final TransactionType initialType;

  static Future<void> show(
    BuildContext context, {
    TransactionModel? existing,
    TransactionType initialType = TransactionType.expense,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TransactionFormSheet(
        existing: existing,
        initialType: initialType,
      ),
    );
  }

  @override
  ConsumerState<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  final _amountFocus = FocusNode();

  late TransactionType _type;
  CategoryModel? _category;
  late DateTime _date;
  late PaymentMethod _paymentMethod;
  late ExpenseScope _expenseScope;
  bool _categoryTouched = false;

  bool get _isEditing => widget.existing != null;
  bool _refund = false;

  bool get _refundAmount => _type.isExpense && _refund;

  void _onAmountEdited() {
    final refund = _amount.text.trim().startsWith('-');
    if (refund == _refund || !mounted) return;
    setState(() => _refund = refund);
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.initialType;
    _category = existing?.category;
    _date = existing?.transactionDate ?? AppDateUtils.today();
    _paymentMethod = existing?.paymentMethod ?? PaymentMethod.cash;
    _expenseScope = existing?.expenseScope ?? ExpenseScope.personal;
    _amount = TextEditingController(
      text: existing == null ? '' : existing.amount.toDecimalString().replaceAll('.00', ''),
    );
    _description = TextEditingController(text: existing?.description ?? '');
    _refund = _amount.text.trim().startsWith('-');
    _amount.addListener(_onAmountEdited);
    if (existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _amount.removeListener(_onAmountEdited);
    _amount.dispose();
    _description.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _switchType(TransactionType type) {
    if (type == _type) return;
    if (type.isIncome && _amount.text.trim().startsWith('-')) {
      final stripped = _amount.text.trim().substring(1);
      _amount.value = TextEditingValue(
        text: stripped,
        selection: TextSelection.collapsed(offset: stripped.length),
      );
    }
    setState(() {
      _type = type;
      _category = null; // categories are type-specific
      _categoryTouched = false;
      // Keep Personal / Joint when switching types so a ₱15k joint contribution
      // does not snap back to personal.
    });
  }

  void _toggleRefund() {
    final text = _amount.text.trim();
    final next = text.startsWith('-') ? text.substring(1) : '-$text';
    _amount.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _amountFocus.requestFocus();
  }

  Future<void> _pickCategory() async {
    final picked = await CategoryPickerSheet.show(
      context,
      type: _type,
      selectedId: _category?.id,
    );
    if (picked != null && mounted) {
      setState(() {
        _category = picked;
        _categoryTouched = true;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Transaction date',
    );
    if (picked != null && mounted) {
      setState(() => _date = AppDateUtils.dateOnly(picked));
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _categoryTouched = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || _category == null) {
      if (_category == null) {
        AppSnackBar.error(context, 'Choose a category');
      }
      return;
    }

    final input = TransactionInput(
      type: _type,
      amount: Money.parse(_amount.text),
      categoryId: _category!.id,
      transactionDate: _date,
      description: _description.text,
      paymentMethod: _type.isExpense ? _paymentMethod : PaymentMethod.cash,
      expenseScope: _expenseScope,
    );

    final controller = ref.read(transactionControllerProvider.notifier);
    final ok = _isEditing
        ? await controller.edit(widget.existing!.id, input)
        : await controller.create(input);

    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
      // The root ScaffoldMessenger shows the snackbar, so it outlives the sheet.
      AppSnackBar.success(
        context,
        _isEditing
            ? 'Transaction updated'
            : '${_type.label} of ${CurrencyFormatter.format(input.amount, currency: ref.read(currencyProvider))} saved',
      );
      Navigator.of(context).pop();
    } else {
      AppSnackBar.error(context, ref.read(transactionControllerProvider).error);
    }
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete transaction?',
      message: 'This will permanently remove "${widget.existing!.title}" '
          'and update the household totals.',
    );
    if (!confirmed || !mounted) return;
    final ok = await ref
        .read(transactionControllerProvider.notifier)
        .delete(widget.existing!.id);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.success(context, 'Transaction deleted');
      Navigator.of(context).pop();
    } else {
      AppSnackBar.error(context, ref.read(transactionControllerProvider).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final saving = ref.watch(transactionControllerProvider).isLoading;
    final currency = ref.watch(currencyProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final accent = _type.isIncome || _refundAmount ? colors.income : colors.expense;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    // Ensure the selected category still matches the type (e.g. after a
    // realtime category update).
    final categories = ref.watch(categoriesByTypeProvider(_type)).value;
    if (_category != null && categories != null) {
      final fresh = categories.where((c) => c.id == _category!.id).firstOrNull;
      if (fresh != null && fresh != _category) _category = fresh;
    }

    return AnimatedPadding(
      duration: AppConstants.animFast,
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 0, 20, sheetBottomPadding(context)),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit transaction' : 'Add transaction',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (_isEditing)
                      IconButton(
                        onPressed: saving ? null : _delete,
                        tooltip: 'Delete',
                        icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                      ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),
                _TypeSwitch(
                  value: _type,
                  onChanged: saving ? null : _switchType,
                ),
                const SizedBox(height: AppConstants.spaceLg),

                // Amount
                Text(
                  'Amount',
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amount,
                  focusNode: _amountFocus,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: _type.isExpense,
                  ),
                  inputFormatters: [
                    AmountInputFormatter(allowNegative: _type.isExpense),
                  ],
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.headlineMedium?.copyWith(color: accent),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    helperText: _type.isExpense
                        ? 'Tap − for a refund or a cancelled charge.'
                        : null,
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_type.isExpense)
                          IconButton(
                            tooltip: 'Refund or cancelled charge',
                            visualDensity: VisualDensity.compact,
                            onPressed: saving ? null : _toggleRefund,
                            icon: Icon(
                              Icons.remove_rounded,
                              color: _refundAmount ? colors.income : scheme.onSurfaceVariant,
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(left: _type.isExpense ? 0 : 16, right: 8),
                          child: Text(
                            CurrencyFormatter.symbol(currency),
                            style: theme.textTheme.headlineSmall?.copyWith(color: accent),
                          ),
                        ),
                      ],
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                  validator: (value) => Validators.amount(
                    value,
                    allowNegative: _type.isExpense,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Category
                _FieldTile(
                  label: 'Category',
                  onTap: saving ? null : _pickCategory,
                  error: _categoryTouched && _category == null ? 'Choose a category' : null,
                  leading: _category == null
                      ? CircleAvatar(
                          radius: 20,
                          backgroundColor: scheme.surfaceContainerHigh,
                          child: Icon(Icons.category_outlined, color: scheme.onSurfaceVariant),
                        )
                      : CategoryIconBadge(
                          iconKey: _category!.icon,
                          colorHex: _category!.color,
                          size: 40,
                        ),
                  value: _category?.name ?? 'Select a category',
                  placeholder: _category == null,
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Description
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  maxLength: AppConstants.maxDescriptionLength,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g. Weekly groceries',
                    prefixIcon: Icon(Icons.notes_rounded),
                    counterText: '',
                  ),
                  validator: Validators.description,
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Date
                _FieldTile(
                  label: 'Date',
                  onTap: saving ? null : _pickDate,
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.event_rounded, color: scheme.onPrimaryContainer),
                  ),
                  value: AppDateUtils.mediumDate(_date),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      _QuickDateChip(
                        label: 'Today',
                        selected: AppDateUtils.isSameDay(_date, AppDateUtils.today()),
                        onTap: () => setState(() => _date = AppDateUtils.today()),
                      ),
                      _QuickDateChip(
                        label: 'Yesterday',
                        selected: AppDateUtils.isSameDay(
                          _date,
                          AppDateUtils.today().subtract(const Duration(days: 1)),
                        ),
                        onTap: () => setState(
                          () => _date = AppDateUtils.today().subtract(const Duration(days: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),

                InputDecorator(
                  decoration: InputDecoration(
                    labelText: _type.isIncome ? 'Income for' : 'Expense for',
                    prefixIcon: const Icon(Icons.groups_outlined),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ExpenseScope>(
                      value: _expenseScope,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: ExpenseScope.personal,
                          child: Text('Personal'),
                        ),
                        DropdownMenuItem(
                          value: ExpenseScope.joint,
                          child: Text('Joint'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _expenseScope = value);
                              }
                            },
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                if (_type.isExpense) ...[
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Mode of payment',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PaymentMethod>(
                        value: _paymentMethod,
                        isExpanded: true,
                        items: [
                          for (final method in PaymentMethod.values)
                            DropdownMenuItem(
                              value: method,
                              child: Text(method.label),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _paymentMethod = value);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceMd),
                ],

                // Paid by stays the signed-in user; scope decides who the expense is for.
                _FieldTile(
                  label: _type.actorLabel,
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.tertiaryContainer,
                    child: Text(
                      profile?.initials ?? '?',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  value: _isEditing
                      ? (widget.existing!.userDisplayName ?? profile?.displayName ?? 'You')
                      : (profile?.displayName ?? 'You'),
                  helper: _type.isIncome
                      ? (_expenseScope == ExpenseScope.joint
                          ? 'This goes into the joint pot.'
                          : 'Income is recorded under your own account.')
                      : _expenseScope == ExpenseScope.joint
                          ? 'You paid. This counts as a shared household expense.'
                          : 'You paid. This counts as your personal expense.',
                ),
                const SizedBox(height: AppConstants.spaceLg),

                PrimaryButton(
                  label: _isEditing ? 'Save changes' : 'Save ${_type.label.toLowerCase()}',
                  loading: saving,
                  onPressed: _save,
                  backgroundColor: accent,
                  foregroundColor: _type.isIncome ? colors.onIncome : colors.onExpense,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated INCOME / EXPENSE segmented switch.
class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.value, required this.onChanged});

  final TransactionType value;
  final ValueChanged<TransactionType>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final isIncome = value.isIncome;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final half = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppConstants.animMedium,
                curve: Curves.easeOutCubic,
                left: isIncome ? 0 : half,
                top: 0,
                bottom: 0,
                width: half,
                child: AnimatedContainer(
                  duration: AppConstants.animMedium,
                  decoration: BoxDecoration(
                    color: isIncome ? colors.income : colors.expense,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                ),
              ),
              Row(
                children: [
                  _TypeButton(
                    label: 'Income',
                    icon: Icons.arrow_downward_rounded,
                    selected: isIncome,
                    onTap: onChanged == null ? null : () => onChanged!(TransactionType.income),
                  ),
                  _TypeButton(
                    label: 'Expense',
                    icon: Icons.arrow_upward_rounded,
                    selected: !isIncome,
                    onTap: onChanged == null ? null : () => onChanged!(TransactionType.expense),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? Colors.white : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: AppConstants.animFast,
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.label,
    required this.leading,
    required this.value,
    this.onTap,
    this.trailing,
    this.error,
    this.helper,
    this.placeholder = false,
  });

  final String label;
  final Widget leading;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? error;
  final String? helper;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borderColor = error != null ? scheme.error : scheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: placeholder ? scheme.onSurfaceVariant : scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ] else if (onTap != null)
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          )
        else if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Text(
              helper!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
