import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../households/application/household_providers.dart';

/// Generates and displays a single-use invite code.
class InviteMemberSheet extends ConsumerStatefulWidget {
  const InviteMemberSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => const InviteMemberSheet(),
    );
  }

  @override
  ConsumerState<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<InviteMemberSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inviteControllerProvider.notifier).generate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final invite = ref.watch(inviteControllerProvider);
    final householdName = ref.watch(currentHouseholdProvider).value?.name ?? 'your household';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invite your partner', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Share this code. They enter it after signing up to join "$householdName". '
            'The code works once and expires in 48 hours.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppConstants.spaceLg),
          AnimatedSwitcher(
            duration: AppConstants.animMedium,
            child: invite.when(
              loading: () => const SizedBox(
                key: ValueKey('loading'),
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorState(
                key: const ValueKey('error'),
                compact: true,
                error: error,
                onRetry: () => ref.read(inviteControllerProvider.notifier).generate(),
              ),
              data: (data) {
                if (data == null) {
                  return const SizedBox(key: ValueKey('empty'), height: 120);
                }
                final expires = DateFormat('EEE, d MMM · h:mm a').format(data.expiresAt);
                return Column(
                  key: ValueKey(data.code),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: SelectableText(
                        data.formattedCode,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          letterSpacing: 4,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Expires $expires',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppConstants.spaceLg),
                    PrimaryButton(
                      label: 'Copy code',
                      icon: Icons.copy_rounded,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: data.formattedCode));
                        if (context.mounted) {
                          AppSnackBar.success(context, 'Invite code copied');
                        }
                      },
                    ),
                    TextButton.icon(
                      onPressed: () => ref.read(inviteControllerProvider.notifier).generate(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Generate a new code'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
