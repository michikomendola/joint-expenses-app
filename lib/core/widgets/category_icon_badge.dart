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
  });

  final String? iconKey;
  final String? colorHex;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.parse(colorHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
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
  }
}
