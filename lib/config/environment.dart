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

  /// Separate from the native-only Google Maps SDK key (Android's
  /// `google_maps_key` string resource / iOS's `Secrets.xcconfig`, see
  /// `lib/core/maps/CLAUDE.md`) — those are wired directly into the native
  /// map SDKs and aren't reachable from Dart. Directions API calls are made
  /// from Dart, so they need their own `--dart-define`-supplied copy of the
  /// same key (the Directions API must also be enabled for it in Google
  /// Cloud Console, separately from the Maps SDK).
  static String get googleMapsApiKey =>
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY');
}
