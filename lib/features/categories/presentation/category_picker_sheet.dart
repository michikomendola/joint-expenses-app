import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/category_icon_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction_type.dart';
import '../application/category_providers.dart';
import 'category_form_sheet.dart';

/// Searchable grid of categories for a transaction type.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  const CategoryPickerSheet({
    super.key,
    required this.type,
    this.selectedId,
    this.excludeId,
    this.title,
  });

  final TransactionType type;
  final String? selectedId;

  /// Hide one category (used when choosing a replacement on delete).
  final String? excludeId;
  final String? title;

  static Future<CategoryModel?> show(
    BuildContext context, {
    required TransactionType type,
    String? selectedId,
    String? excludeId,
    String? title,
  }) {
    return showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CategoryPickerSheet(
        type: type,
        selectedId: selectedId,
        excludeId: excludeId,
        title: title,
      ),
    );
  }

  @override
  ConsumerState<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesByTypeProvider(widget.type));
    final height = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title ?? 'Choose a ${widget.type.label.toLowerCase()} category',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final created = await CategoryFormSheet.show(
                          context,
                          type: widget.type,
                        );
                        if (created != null && context.mounted) {
                          Navigator.of(context).pop(created);
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search categories',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                error: error,
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
              data: (all) {
                final needle = _query.trim().toLowerCase();
                final items = all
                    .where((c) => c.id != widget.excludeId)
                    .where((c) => needle.isEmpty || c.name.toLowerCase().contains(needle))
                    .toList();
                if (items.isEmpty) {
                  return EmptyState(
                    compact: true,
                    icon: Icons.search_off_rounded,
                    title: needle.isEmpty ? 'No categories yet' : 'No matches',
                    message: needle.isEmpty
                        ? 'Create one with the New button.'
                        : 'Try a different search or create a new category.',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 96,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final c = items[index];
                    final selected = c.id == widget.selectedId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      onTap: () => Navigator.of(context).pop(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            CategoryIconBadge(
                              iconKey: c.icon,
                              colorHex: c.color,
                              size: 52,
                              selected: selected,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.name,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: selected ? FontWeight.w700 : null,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
