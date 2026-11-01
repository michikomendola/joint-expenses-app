import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../../authentication/application/auth_providers.dart';
import '../application/household_providers.dart';

enum _Mode { choose, create, join }

/// First screen after sign-up: create a household or join one with a code.
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  _Mode _mode = _Mode.choose;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Our Finances');
  final _code = TextEditingController();
  String _currency = AppConstants.defaultCurrency;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(currentHouseholdProvider.notifier);
      if (_mode == _Mode.create) {
        await notifier.create(_name.text, currency: _currency);
      } else {
        await notifier.join(_code.text);
      }
      // Router redirects to home once the household is set.
    } catch (error) {
      if (mounted) AppSnackBar.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: _mode != _Mode.choose
            ? IconButton(
                onPressed: _busy ? null : () => setState(() => _mode = _Mode.choose),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        actions: [
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spaceLg, 0, AppConstants.spaceLg, AppConstants.spaceLg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AnimatedSwitcher(
                duration: AppConstants.animMedium,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: switch (_mode) {
                  _Mode.choose => _ChooseView(
                      key: const ValueKey('choose'),
                      greetingName: profile?.displayName,
                      onCreate: () => setState(() => _mode = _Mode.create),
                      onJoin: () => setState(() => _mode = _Mode.join),
                    ),
                  _Mode.create => _FormView(
                      key: const ValueKey('create'),
                      formKey: _formKey,
                      title: 'Name your household',
                      subtitle: 'You can rename it anytime in Settings.',
                      busy: _busy,
                      submitLabel: 'Create household',
                      onSubmit: _submit,
                      fields: [
                        TextFormField(
                          controller: _name,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          maxLength: AppConstants.maxHouseholdNameLength,
                          decoration: const InputDecoration(
                            labelText: 'Household name',
                            prefixIcon: Icon(Icons.home_outlined),
                            counterText: '',
                          ),
                          validator: Validators.householdName,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          items: [
                            for (final c in CurrencyFormatter.supported)
                              DropdownMenuItem(
                                value: c.code,
                                child: Text('${c.code} · ${c.name}'),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _currency = value ?? 'PHP'),
                        ),
                      ],
                    ),
                  _Mode.join => _FormView(
                      key: const ValueKey('join'),
                      formKey: _formKey,
                      title: 'Enter your invite code',
                      subtitle: 'Ask your partner to share the code from '
                          'Settings → Invite member.',
                      busy: _busy,
                      submitLabel: 'Join household',
                      onSubmit: _submit,
                      fields: [
                        TextFormField(
                          controller: _code,
                          autofocus: true,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                            LengthLimitingTextInputFormatter(11),
                            const _UpperCaseFormatter(),
                          ],
                          style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 2),
                          decoration: InputDecoration(
                            labelText: 'Invite code',
                            hintText: 'ABCDE-FGHJK',
                            prefixIcon: const Icon(Icons.key_rounded),
                            suffixIcon: IconButton(
                              tooltip: 'Paste',
                              icon: const Icon(Icons.content_paste_rounded),
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null) {
                                  _code.text = data!.text!.trim().toUpperCase();
                                }
                              },
                            ),
                          ),
                          validator: Validators.inviteCode,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                },
              ),
            ),
          ),
        ),
      ),
      backgroundColor: scheme.surface,
    );
  }
}

class _ChooseView extends StatelessWidget {
  const _ChooseView({
    super.key,
    required this.greetingName,
    required this.onCreate,
    required this.onJoin,
  });

  final String? greetingName;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.spaceMd),
        Text(
          greetingName == null ? 'Welcome!' : 'Welcome, $greetingName!',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        Text(
          'A household is the shared space where you and your partner '
          'track income and expenses together.',
          style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppConstants.spaceXl),
        AnimatedEntrance(
          child: _OptionCard(
            icon: Icons.add_home_rounded,
            color: scheme.primary,
            title: 'Create a household',
            subtitle: "Start fresh and invite your partner afterwards.",
            onTap: onCreate,
          ),
        ),
        const SizedBox(height: AppConstants.spaceMd),
        AnimatedEntrance(
          delay: const Duration(milliseconds: 80),
          child: _OptionCard(
            icon: Icons.group_add_rounded,
            color: scheme.tertiary,
            title: 'Join with an invite code',
            subtitle: 'Your partner already created one? Enter their code.',
            onTap: onJoin,
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    super.key,
    required this.formKey,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.busy,
    required this.submitLabel,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String subtitle;
  final List<Widget> fields;
  final bool busy;
  final String submitLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppConstants.spaceMd),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppConstants.spaceLg),
          ...fields,
          const SizedBox(height: AppConstants.spaceLg),
          PrimaryButton(label: submitLabel, loading: busy, onPressed: onSubmit),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
