import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signUp({
    required String email,
    required String password,
    required DateTime dateOfBirth,
    String? displayName,
  });

  Future<UserModel> login({required String email, required String password});

  Future<void> logout();

  Future<UserModel> refreshSession();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> resetPassword({required String newPassword});

  Future<UserModel?> getCurrentUser();

  Future<UserModel> updateProfile({String? displayName, String? avatarUrl});

  Future<void> verifyEmail(String token);

  bool isAuthenticated();

  Future<void> deleteAccount();

  Future<Map<String, dynamic>> exportOwnData();

  /// Completes the age gate for an already-created (invite-path) account —
  /// see `stage44_age_gate.sql`'s `confirm_age_and_finish_signup()` for why
  /// this exists as a separate step instead of being checked at signup for
  /// every path. Returns `true` if verified 18+, `false` if the account was
  /// just rejected (and deleted server-side) for being under 18.
  Future<bool> confirmAge(DateTime dateOfBirth);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl();

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required DateTime dateOfBirth,
    String? displayName,
  }) async {
    try {
      // date_of_birth is read once by the server-side age-gate trigger
      // (stage44_age_gate.sql) and stripped out of raw_user_meta_data
      // before the row is ever persisted — see that migration's header
      // comment. Sent as a plain date string (no time/zone component).
      final response = await KumoSupabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {
          if (displayName != null) 'display_name': displayName,
          'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        },
      );
      final user = response.user;
      if (user == null) {
        throw AuthException(message: 'Sign up failed: no user returned');
      }
      return UserModel.fromSupabaseUser(user);
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await KumoSupabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw AuthException.invalidCredentials();
      }
      return UserModel.fromSupabaseUser(user);
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await KumoSupabaseClient.auth.signOut();
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<UserModel> refreshSession() async {
    try {
      final response = await KumoSupabaseClient.auth.refreshSession();
      final user = response.user;
      if (user == null) {
        throw AuthException.sessionExpired();
      }
      return UserModel.fromSupabaseUser(user);
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await KumoSupabaseClient.auth.resetPasswordForEmail(
        email,
        redirectTo: 'kumo://reset-password',
      );
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> resetPassword({required String newPassword}) async {
    try {
      await KumoSupabaseClient.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = KumoSupabaseClient.auth.currentUser;
    if (user == null) {
      return null;
    }
    return UserModel.fromSupabaseUser(user);
  }

  @override
  Future<UserModel> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (displayName != null) {
        data['display_name'] = displayName;
      }
      if (avatarUrl != null) {
        data['avatar_url'] = avatarUrl;
      }

      final response = await KumoSupabaseClient.auth.updateUser(
        sb.UserAttributes(data: data),
      );
      final user = response.user;
      if (user == null) {
        throw AuthException(message: 'Profile update failed');
      }
      return UserModel.fromSupabaseUser(user);
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> verifyEmail(String token) async {
    try {
      await KumoSupabaseClient.auth.verifyOTP(
        token: token,
        type: sb.OtpType.email,
      );
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  bool isAuthenticated() => KumoSupabaseClient.isAuthenticated;

  @override
  Future<void> deleteAccount() async {
    try {
      await KumoSupabaseClient.client.rpc('delete_user');
      await KumoSupabaseClient.auth.signOut();
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> exportOwnData() async {
    try {
      final result = await KumoSupabaseClient.client.rpc('export_own_data');
      return result as Map<String, dynamic>;
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<bool> confirmAge(DateTime dateOfBirth) async {
    try {
      final result = await KumoSupabaseClient.client.rpc(
        'confirm_age_and_finish_signup',
        params: {
          'p_date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        },
      );
      return result == 'verified';
    } on sb.AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
