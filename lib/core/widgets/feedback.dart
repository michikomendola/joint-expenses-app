import 'package:flutter/material.dart';

import '../utils/app_error.dart';

/// Snackbar helpers so feedback looks the same everywhere.
abstract final class AppSnackBar {
  static void success(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_rounded,
      background: Theme.of(context).colorScheme.inverseSurface,
      foreground: Theme.of(context).colorScheme.onInverseSurface,
    );
  }

  static void error(BuildContext context, Object? error) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      error is String ? error : AppError.message(error),
      icon: Icons.error_outline_rounded,
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
    );
  }

  static void info(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message,
      icon: Icons.info_outline_rounded,
      background: scheme.inverseSurface,
      foreground: scheme.onInverseSurface,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          content: Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: TextStyle(color: foreground)),
              ),
            ],
          ),
        ),
      );
  }
}

/// Confirmation dialog for destructive actions. Resolves to `true` when the
/// user confirms.
abstract final class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    bool destructive = true,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    minimumSize: const Size(0, 44),
                  )
                : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
