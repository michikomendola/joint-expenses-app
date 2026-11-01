import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Full-width filled button with an inline loading indicator.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final style = (backgroundColor != null || foregroundColor != null)
        ? FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
          )
        : null;
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: AnimatedSwitcher(
        duration: AppConstants.animFast,
        child: loading
            ? SizedBox(
                key: const ValueKey('loading'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: foregroundColor ?? Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
