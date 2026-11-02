import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/category_icons.dart';
import '../../../core/utils/system_insets.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/category_icon_badge.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction_type.dart';
import '../application/category_providers.dart';
import 'category_picker_sheet.dart';

/// Create or edit a category: name, icon and colour.
class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key, required this.type, this.existing});

  final TransactionType type;
  final CategoryModel? existing;

  /// Returns the created/updated category, or null when cancelled.
  static Future<CategoryModel?> show(
    BuildContext context, {
    required TransactionType type,
    CategoryModel? existing,
  }) {
    return showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CategoryFormSheet(type: type, existing: existing),
    );
  }

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? CategoryIcons.fallbackKey;
  late String _color = widget.existing?.color ?? CategoryColors.palette.first;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final input = CategoryInput(
      name: _name.text,
      type: widget.type,
      icon: _icon,
      color: _color,
    );
    final controller = ref.read(categoryControllerProvider.notifier);
    final saved = _isEditing
        ? await controller.edit(widget.existing!.id, input)
        : await controller.create(input);
    if (!mounted) return;
    if (saved == null) {
      AppSnackBar.error(context, ref.read(categoryControllerProvider).error);
      return;
    }
    AppSnackBar.success(context, _isEditing ? 'Category updated' : 'Category created');
    Navigator.of(context).pop(saved);
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final controller = ref.read(categoryControllerProvider.notifier);

    int usage;
    try {
      usage = await controller.countUsage(existing.id);
    } catch (error) {
      if (mounted) AppSnackBar.error(context, error);
      return;
    }
    if (!mounted) return;

    String? replacementId;
    if (usage > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Category in use'),
          content: Text(
            '"${existing.name}" is used by $usage '
            '${usage == 1 ? 'transaction' : 'transactions'}. '
            'Choose another ${existing.type.label.toLowerCase()} category to move them to '
            'before deleting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Choose replacement'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      final replacement = await CategoryPickerSheet.show(
        context,
        type: existing.type,
        excludeId: existing.id,
        title: 'Move transactions to…',
      );
      if (replacement == null || !mounted) return;
      replacementId = replacement.id;
    } else {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Delete category?',
        message: '"${existing.name}" is not used by any transaction and will be removed.',
      );
      if (!confirmed || !mounted) return;
    }

    final ok = await controller.delete(existing.id, replacementId: replacementId);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.success(
        context,
        usage > 0
            ? 'Category deleted · $usage ${usage == 1 ? 'transaction' : 'transactions'} moved'
            : 'Category deleted',
      );
      Navigator.of(context).pop();
    } else {
      AppSnackBar.error(context, ref.read(categoryControllerProvider).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final saving = ref.watch(categoryControllerProvider).isLoading;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return AnimatedPadding(
      duration: AppConstants.animFast,
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
                        _isEditing
                            ? 'Edit category'
                            : 'New ${widget.type.label.toLowerCase()} category',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (_isEditing)
                      IconButton(
                        onPressed: saving ? null : _delete,
                        tooltip: 'Delete category',
                        icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                      ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Center(
                  child: CategoryIconBadge(
                    iconKey: _icon,
                    colorHex: _color,
                    size: 72,
                    selected: true,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                TextFormField(
                  controller: _name,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  maxLength: AppConstants.maxCategoryNameLength,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Pets',
                    counterText: '',
                  ),
                  validator: Validators.categoryName,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: AppConstants.spaceLg),
                Text('Colour', style: theme.textTheme.labelLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final hex in CategoryColors.palette)
                      _ColorDot(
                        color: CategoryColors.parse(hex),
                        selected: hex == _color,
                        onTap: () => setState(() => _color = hex),
                      ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceLg),
                Text('Icon', style: theme.textTheme.labelLarge),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 56,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: CategoryIcons.all.length,
                  itemBuilder: (context, index) {
                    final key = CategoryIcons.keys[index];
                    final selected = key == _icon;
                    return Semantics(
                      selected: selected,
                      button: true,
                      label: key.replaceAll('_', ' '),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _icon = key),
                        child: AnimatedContainer(
                          duration: AppConstants.animFast,
                          decoration: BoxDecoration(
                            color: selected
                                ? CategoryColors.parse(_color).withValues(alpha: 0.18)
                                : scheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? CategoryColors.parse(_color) : Colors.transparent,
                              width: 1.6,
                            ),
                          ),
                          child: Icon(
                            CategoryIcons.all[key],
                            color: selected ? CategoryColors.parse(_color) : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppConstants.spaceLg),
                PrimaryButton(
                  label: _isEditing ? 'Save changes' : 'Create category',
                  loading: saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
        ),
      ),
    );
  }
}
