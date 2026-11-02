import 'package:flutter/material.dart';

import '../constants/category_icons.dart';

/// Circular, tinted icon used for categories throughout the app.
class CategoryIconBadge extends StatelessWidget {
  const CategoryIconBadge({
    super.key,
    required this.iconKey,
    required this.colorHex,
    this.size = 44,
    this.selected = false,
    this.paid = false,
  });

  final String? iconKey;
  final String? colorHex;
  final double size;
  final bool selected;

  /// Small green check on the corner. Used for paid joint expenses.
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.parse(colorHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? color : color.withValues(alpha: isDark ? 0.22 : 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        CategoryIcons.resolve(iconKey),
        size: size * 0.5,
        color: selected ? Colors.white : color,
      ),
    );
    if (!paid) return badge;

    const mark = 18.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          badge,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: mark,
              height: mark,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1F9D63),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
