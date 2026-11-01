import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../utils/app_error.dart';

/// Friendly empty state with an optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.spaceLg,
        vertical: compact ? AppConstants.spaceMd : AppConstants.spaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 28 : 34,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppConstants.spaceMd),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state with retry.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.spaceLg,
        vertical: compact ? AppConstants.spaceMd : AppConstants.spaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: compact ? 32 : 44, color: scheme.error),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            AppError.message(error),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppConstants.spaceMd),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Title row with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 0, 10),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
