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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    if (!ok) {
      AppSnackBar.error(context, ref.read(authControllerProvider).error);
    }
    // On success the router redirects automatically.
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to see your shared finances.',
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            "Don't have an account?",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          TextButton(
            onPressed: loading ? null : () => context.push(AppRoutes.signUp),
            child: const Text('Create one'),
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                ),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Password is required' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: loading ? null : () => context.push(AppRoutes.forgotPassword),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            PrimaryButton(
              label: 'Sign in',
              loading: loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
