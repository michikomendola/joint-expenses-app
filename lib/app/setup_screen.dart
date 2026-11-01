import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../core/widgets/app_card.dart';

/// Displayed when the app was built without Supabase credentials.
/// It explains exactly how to connect a backend instead of pretending one
/// exists.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  static const String _command =
      'flutter run --dart-define-from-file=env.json';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spaceLg),
          children: [
            const SizedBox(height: AppConstants.spaceXl),
            Icon(Icons.cloud_off_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: AppConstants.spaceMd),
            Text(
              'Backend not configured',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              'Joint Expenses needs a Supabase project. Follow these steps, '
              'then rebuild the app.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceLg),
            const _Step(
              number: 1,
              title: 'Create a Supabase project',
              body: 'Go to supabase.com, create a project and open '
                  'Project Settings → API to copy the Project URL and anon key.',
            ),
            const _Step(
              number: 2,
              title: 'Run the SQL migrations',
              body: 'Execute the files in supabase/migrations/ in order using the '
                  'SQL editor (or `supabase db push`).',
            ),
            const _Step(
              number: 3,
              title: 'Create env.json',
              body: 'Copy env.example.json to env.json and fill in '
                  'SUPABASE_URL and SUPABASE_ANON_KEY. Never use the service-role key.',
            ),
            _Step(
              number: 4,
              title: 'Run with the environment file',
              body: _command,
              mono: true,
              onCopy: () {
                Clipboard.setData(const ClipboardData(text: _command));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Command copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.mono = false,
    this.onCopy,
  });

  final int number;
  final String title;
  final String body;
  final bool mono;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceMd),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                '$number',
                style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: AppConstants.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: mono
                        ? theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: scheme.primary,
                          )
                        : theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                  ),
                ],
              ),
            ),
            if (onCopy != null)
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy',
              ),
          ],
        ),
      ),
    );
  }
}
