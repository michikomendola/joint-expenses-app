import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Rounded surface with a soft shadow – the basic building block of the UI.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppConstants.spaceMd),
    this.color,
    this.gradient,
    this.onTap,
    this.borderRadius = AppConstants.radiusLg,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? scheme.surfaceContainerLowest) : null,
        gradient: gradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: context.appColors.cardShadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}
