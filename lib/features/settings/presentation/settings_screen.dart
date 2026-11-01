import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/household.dart';
import '../../authentication/application/auth_providers.dart';
import '../../households/application/household_providers.dart';
import '../application/settings_providers.dart';
import 'invite_member_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(currentProfileProvider);
    final user = ref.watch(currentUserProvider);
    final household = ref.watch(currentHouseholdProvider).value;
    final members = ref.watch(householdMembersProvider);
    final themeMode = ref.watch(themeModeProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppConstants.spaceMd, 4, AppConstants.spaceMd, bottomInset + 120,
        ),
        children: [
          // ------------------------------------------------------------ Profile
          _Section(
            title: 'Profile',
            children: [
              profile.when(
                loading: () => const SkeletonTile(),
                error: (error, _) => ListTile(
                  leading: Icon(Icons.error_outline_rounded, color: scheme.error),
                  title: const Text('Could not load profile'),
                  trailing: TextButton(
                    onPressed: () => ref.invalidate(currentProfileProvider),
                    child: const Text('Retry'),
                  ),
                ),
                data: (p) => ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      p?.initials ?? '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(p?.displayName ?? 'Member'),
                  subtitle: Text(p?.email ?? user?.email ?? ''),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _editText(
                    context,
                    title: 'Your name',
                    initial: p?.displayName ?? '',
                    maxLength: AppConstants.maxDisplayNameLength,
                    validator: Validators.displayName,
                    onSave: (value) async {
                      final ok = await ref
                          .read(authControllerProvider.notifier)
                          .updateDisplayName(value);
                      if (!ok) throw ref.read(authControllerProvider).error!;
                      ref.invalidate(householdMembersProvider);
                    },
                  ),
                ),
              ),
            ],
          ),

          // ---------------------------------------------------------- Household
          _Section(
            title: 'Household',
            children: [
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Household name'),
                subtitle: Text(household?.name ?? '—'),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: household == null
                    ? null
                    : () => _editText(
                          context,
                          title: 'Household name',
                          initial: household.name,
                          maxLength: AppConstants.maxHouseholdNameLength,
                          validator: Validators.householdName,
                          onSave: (value) =>
                              ref.read(currentHouseholdProvider.notifier).rename(value),
                        ),
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Currency'),
                subtitle: Text(
                  household == null
                      ? '—'
                      : '${household.currency} · ${CurrencyFormatter.currency(household.currency).name}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: household == null ? null : () => _pickCurrency(context, ref, household),
              ),
            ],
          ),

          // ------------------------------------------------------------ Members
          _Section(
            title: 'Members',
            trailing: TextButton.icon(
              onPressed: household == null ? null : () => InviteMemberSheet.show(context),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Invite'),
            ),
            children: [
              members.when(
                loading: () => const Column(children: [SkeletonTile(), SkeletonTile()]),
                error: (error, _) => ListTile(
                  leading: Icon(Icons.error_outline_rounded, color: scheme.error),
                  title: const Text('Could not load members'),
                  trailing: TextButton(
                    onPressed: () => ref.invalidate(householdMembersProvider),
                    child: const Text('Retry'),
                  ),
                ),
                data: (list) => Column(
                  children: [
                    for (final m in list)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: m.userId == user?.id
                              ? scheme.primaryContainer
                              : scheme.tertiaryContainer,
                          child: Text(
                            m.profile?.initials ?? '?',
                            style: TextStyle(
                              color: m.userId == user?.id
                                  ? scheme.onPrimaryContainer
                                  : scheme.onTertiaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(m.userId == user?.id ? '${m.displayName} (You)' : m.displayName),
                        subtitle: Text(m.profile?.email ?? m.role.label),
                        trailing: m.role == MemberRole.owner
                            ? Chip(
                                label: const Text('Owner'),
                                visualDensity: VisualDensity.compact,
                                labelStyle: theme.textTheme.labelSmall,
                                padding: EdgeInsets.zero,
                                backgroundColor: scheme.surfaceContainer,
                                side: BorderSide.none,
                              )
                            : null,
                      ),
                    if (list.length < 2)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 18, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Invite your partner so you can track finances together.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // --------------------------------------------------------- Appearance
          _Section(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    ),
                  ],
                  selected: {themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) =>
                      ref.read(themeModeProvider.notifier).set(set.first),
                ),
              ),
            ],
          ),

          // ------------------------------------------------------------ Account
          _Section(
            title: 'Account',
            children: [
              ListTile(
                leading: Icon(Icons.logout_rounded, color: scheme.error),
                title: Text('Sign out', style: TextStyle(color: scheme.error)),
                onTap: () async {
                  final confirmed = await ConfirmDialog.show(
                    context,
                    title: 'Sign out?',
                    message: 'You can sign back in anytime. Your household data stays safe.',
                    confirmLabel: 'Sign out',
                    destructive: false,
                  );
                  if (confirmed) {
                    await ref.read(authControllerProvider.notifier).signOut();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Center(
            child: Text(
              '${AppConstants.appName} · v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required int maxLength,
    required String? Function(String?) validator,
    required Future<void> Function(String value) onSave,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EditTextDialog(
        title: title,
        initial: initial,
        maxLength: maxLength,
        validator: validator,
        onSave: onSave,
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref, Household household) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Currency', style: Theme.of(context).textTheme.titleLarge),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Amounts are not converted – this only changes the symbol and formatting.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            Expanded(
              child: RadioGroup<String>(
                groupValue: household.currency,
                onChanged: (value) => Navigator.of(context).pop(value),
                child: ListView(
                  children: [
                    for (final c in CurrencyFormatter.supported)
                      RadioListTile<String>(
                        value: c.code,
                        title: Text('${c.code} · ${c.name}'),
                        secondary: SizedBox(
                          width: 44,
                          child: Text(
                            c.symbol.trim(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked == household.currency || !context.mounted) return;
    try {
      await ref.read(currentHouseholdProvider.notifier).changeCurrency(picked);
      if (context.mounted) AppSnackBar.success(context, 'Currency set to $picked');
    } catch (error) {
      if (context.mounted) AppSnackBar.error(context, error);
    }
  }
}

/// Single-field edit dialog with validation and async save.
class _EditTextDialog extends StatefulWidget {
  const _EditTextDialog({
    required this.title,
    required this.initial,
    required this.maxLength,
    required this.validator,
    required this.onSave,
  });

  final String title;
  final String initial;
  final int maxLength;
  final String? Function(String?) validator;
  final Future<void> Function(String value) onSave;

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text.trim());
      if (!mounted) return;
      AppSnackBar.success(context, 'Saved');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          validator: widget.validator,
          decoration: const InputDecoration(counterText: ''),
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
            child: Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                ?trailing,
              ],
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
