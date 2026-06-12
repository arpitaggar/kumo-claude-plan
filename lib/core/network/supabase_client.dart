import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/environment.dart';
import '../utils/logger.dart';

/// Supabase client initialization and configuration.
///
/// Provides centralized access to Supabase throughout the app.
/// Call [KumoSupabaseClient.initialize] during app startup.
class KumoSupabaseClient {
  KumoSupabaseClient._(); // Private constructor

  static late Supabase _supabaseInstance;

  /// Initializes the Supabase client.
  ///
  /// Must be called once during app startup before any other Supabase operations.
  ///
  /// @throws Exception if initialization fails
  static Future<void> initialize() async {
    try {
      _supabaseInstance = await Supabase.initialize(
        url: Environment.supabaseUrl,
        publishableKey: Environment.supabaseAnonKey,
      );
      AppLogger.info('Supabase initialized successfully');
    } catch (e, st) {
      AppLogger.critical(
        'Failed to initialize Supabase',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Get the Supabase client instance.
  static Supabase get instance => _supabaseInstance;

  /// Get the Supabase client convenience accessor.
  static SupabaseClient get client => _supabaseInstance.client;

  /// Get the authentication client.
  static GoTrueClient get auth => client.auth;

  /// Get the database client for a specific table.
  static SupabaseQueryBuilder getTable(String table) => client.from(table);

  /// Get the realtime client.
  static RealtimeClient get realtime => client.realtime;

  /// Get the storage client.
  static SupabaseStorageClient get storage => client.storage;

  /// Check if user is authenticated.
  static bool get isAuthenticated => auth.currentSession != null;

  /// Get current authenticated user.
  static User? get currentUser => auth.currentUser;

  /// Get current session.
  static Session? get currentSession => auth.currentSession;

  /// Get access token for the current session.
  static String? get accessToken => currentSession?.accessToken;

  /// Sign out the current user.
  static Future<void> signOut() async {
    try {
      await auth.signOut();
      AppLogger.info('User signed out successfully');
    } catch (e, st) {
      AppLogger.error('Failed to sign out', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Refresh the current session.
  static Future<AuthResponse> refreshSession() async {
    try {
      final response = await auth.refreshSession();
      AppLogger.info('Session refreshed successfully');
      return response;
    } catch (e, st) {
      AppLogger.error('Failed to refresh session', error: e, stackTrace: st);
      rethrow;
    }
  }
}
