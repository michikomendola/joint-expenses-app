import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/auth_providers.dart';
import 'widgets/auth_scaffold.dart';

/// Reached through the password-recovery deep link.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(_password.text);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.success(context, 'Password updated');
      // passwordRecoveryProvider is reset → router sends us home.
    } else {
      AppSnackBar.error(context, ref.read(authControllerProvider).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Pick something memorable and at least '
          '${AppConstants.minPasswordLength} characters long.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'New password',
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
              label: 'Update password',
              loading: loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
