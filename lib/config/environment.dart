import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppEnvironment { development, staging, production }

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

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment('SUPABASE_URL');

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get anthropicApiKey =>
      dotenv.env['ANTHROPIC_API_KEY'] ??
      const String.fromEnvironment('ANTHROPIC_API_KEY');
}
