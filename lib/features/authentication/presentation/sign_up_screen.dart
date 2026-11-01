import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/auth_providers.dart';
import 'widgets/auth_scaffold.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _awaitingConfirmation = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final result = await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
    if (!mounted) return;
    if (result == null) {
      AppSnackBar.error(context, ref.read(authControllerProvider).error);
      return;
    }
    if (result == false) {
      // E-mail confirmation is enabled on the project.
      setState(() => _awaitingConfirmation = true);
    }
    // When a session exists the router redirects to onboarding.
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;

    if (_awaitingConfirmation) {
      return AuthScaffold(
        showBack: true,
        title: 'Check your inbox',
        subtitle: 'We sent a confirmation link to ${_email.text.trim()}. '
            'Open it on this device, then sign in.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 72, color: scheme.primary),
            const SizedBox(height: AppConstants.spaceLg),
            PrimaryButton(
              label: 'Back to sign in',
              onPressed: () => context.go(AppRoutes.login),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      showBack: true,
      title: 'Create your account',
      subtitle: 'One account, one shared household.',
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already have an account?',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          TextButton(
            onPressed: loading ? null : () => context.go(AppRoutes.login),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              maxLength: AppConstants.maxDisplayNameLength,
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
              validator: Validators.displayName,
            ),
            const SizedBox(height: AppConstants.spaceMd),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: AppConstants.spaceMd),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least ${AppConstants.minPasswordLength} characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: AppConstants.spaceMd),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              validator: (value) => Validators.confirmPassword(value, _password.text),
            ),
            const SizedBox(height: AppConstants.spaceLg),
            PrimaryButton(
              label: 'Create account',
              loading: loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
