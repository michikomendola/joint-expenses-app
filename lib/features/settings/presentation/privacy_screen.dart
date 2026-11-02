import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// In-app disclosure of the data this app collects and why.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 32),
        children: [
          Text(
            'Joint Expenses stores only what the household needs to track shared money.',
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppConstants.spaceLg),
          const _Block(
            title: 'Account',
            body:
                'Your name, email, and password are used to sign you in and to show you to the other member of your household. The password is stored by the sign-in service, not in the app.',
          ),
          const _Block(
            title: 'Household records',
            body:
                'Household name, currency, members, categories, and the income and expenses you enter are saved so both of you can see the same budget.',
          ),
          const _Block(
            title: 'Statement files',
            body:
                'Before a statement is opened, the app asks you to allow access. If you allow it, your device\'s file picker opens and you choose one PDF. The app reads only that file, on this device, to find purchases, installments, and cardholders. It does not browse the rest of your files, and it does not ask for access to all files on the device.\n\n'
                'The PDF itself is not uploaded. The file name and the transactions you confirm are saved with your household. Full card numbers are hashed and never shown.',
          ),
          const _Block(
            title: 'Deleting your account',
            body:
                'Settings → Account → Delete account removes your sign-in, name, and email. If you are the only member, the household and its records are deleted too. If a partner is still a member, the household stays with them. Expenses marked personal to you are deleted. Shared expenses stay so your partner does not lose the household history.',
          ),
          Text(
            'Joint Expenses does not show ads and does not sell this data.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
