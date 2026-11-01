/// Compile-time environment configuration.
///
/// Values are injected with `--dart-define` / `--dart-define-from-file` so no
/// secrets are ever committed to the repository. The anon key is safe to ship
/// in the app; the service-role key must never be used here.
abstract final class AppEnv {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deep-link scheme used for password recovery and e-mail confirmation.
  static const String deepLinkScheme = 'jointexpenses';
  static const String passwordResetRedirect =
      '$deepLinkScheme://reset-password';
  static const String loginCallbackRedirect = '$deepLinkScheme://login-callback';

  /// True when both values are present and are not the `env.example.json`
  /// placeholders.
  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      !supabaseUrl.contains('YOUR-PROJECT-REF') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.startsWith('YOUR-');
}
