enum AppEnvironment { development, staging, production }

/// Configuration resolved entirely at build time via `--dart-define`/
/// `--dart-define-from-file`, never from a bundled asset file (see
/// docs/SECURITY_AUDIT.md SEC-002 — a file declared under pubspec.yaml's
/// `assets:` ships verbatim inside the compiled APK/IPA, which is exactly
/// the property a "local secrets file" must not have).
class Environment {
  Environment._();

  static AppEnvironment get current {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    return switch (env) {
      'production' => AppEnvironment.production,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.development,
    };
  }

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isProduction => current == AppEnvironment.production;

  static String get supabaseUrl => const String.fromEnvironment('SUPABASE_URL');

  static String get supabaseAnonKey =>
      const String.fromEnvironment('SUPABASE_ANON_KEY');
}
