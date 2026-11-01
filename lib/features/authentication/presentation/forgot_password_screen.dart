import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/auth_providers.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _sent = true);
    } else {
      AppSnackBar.error(context, ref.read(authControllerProvider).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;

    if (_sent) {
      return AuthScaffold(
        showBack: true,
        title: 'Email sent',
        subtitle: 'If an account exists for ${_email.text.trim()}, you will '
            'receive a link to reset your password. Open it on this device.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 72, color: scheme.primary),
            const SizedBox(height: AppConstants.spaceLg),
            PrimaryButton(
              label: 'Back to sign in',
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      showBack: true,
      title: 'Reset password',
      subtitle: "Enter your email and we'll send you a reset link.",
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: AppConstants.spaceLg),
            PrimaryButton(
              label: 'Send reset link',
              loading: loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
