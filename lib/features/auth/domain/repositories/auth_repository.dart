import 'package:dartz/dartz.dart';
import '../../../../core/error/failure.dart';
import '../entities/user.dart';

/// Abstract repository defining authentication operations.
///
/// Implementations should handle all authentication flows including
/// signup, login, password reset, session management, and MFA.
///
/// Returns [Either<Failure, T>] for type-safe error handling without exceptions.
abstract class AuthRepository {
  /// Signs up a new user with email and password.
  ///
  /// @param email The user's email address (must be valid and unique)
  /// @param password The user's password (must meet strength requirements)
  /// @param displayName Optional display name for the user
  ///
  /// @returns [Either] containing [User] on success or [AuthFailure] on failure
  ///
  /// Possible failures:
  /// - [AuthFailure] if email already exists
  /// - [ValidationFailure] if input is invalid
  /// - [NetworkFailure] if backend is unreachable
  /// - [ServerFailure] if backend error occurs
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepository.signUp(
  ///   email: 'user@example.com',
  ///   password: 'SecurePass123',
  ///   displayName: 'John Doe',
  /// );
  ///
  /// result.fold(
  ///   (failure) => print('Error: $failure'),
  ///   (user) => print('Signed up: ${user.email}'),
  /// );
  /// ```
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Logs in an existing user with email and password.
  ///
  /// @param email The user's email address
  /// @param password The user's password
  ///
  /// @returns [Either] containing [User] on success or [AuthFailure] on failure
  ///
  /// Possible failures:
  /// - [AuthFailure.invalidCredentials] if email/password is wrong
  /// - [AuthFailure] if user account not found
  /// - [NetworkFailure] if backend is unreachable
  /// - [ServerFailure] if backend error occurs
  ///
  /// Side effects:
  /// - Access token and refresh token are stored securely
  /// - Session is established
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepository.login(
  ///   email: 'user@example.com',
  ///   password: 'SecurePass123',
  /// );
  /// ```
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  });

  /// Logs out the current user and clears session.
  ///
  /// @returns [Either] containing void on success or [AuthFailure] on failure
  ///
  /// Side effects:
  /// - Access token is cleared
  /// - Session is terminated
  /// - User is unauthenticated
  ///
  /// Example:
  /// ```dart
  /// await authRepository.logout();
  /// ```
  Future<Either<Failure, void>> logout();

  /// Refreshes the current session using the refresh token.
  ///
  /// Called automatically when access token is about to expire.
  /// Can also be called manually to update session.
  ///
  /// @returns [Either] containing [User] on success or [AuthFailure] on failure
  ///
  /// Possible failures:
  /// - [AuthFailure.sessionExpired] if refresh token invalid
  /// - [NetworkFailure] if backend is unreachable
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepository.refreshSession();
  /// ```
  Future<Either<Failure, User>> refreshSession();

  /// Sends a password reset email to the user.
  ///
  /// User must click the link in the email to proceed with password reset.
  /// Email contains a time-limited token (valid for 24 hours).
  ///
  /// @param email The user's email address
  ///
  /// @returns [Either] containing void on success or [Failure] on failure
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if email not found
  /// - [NetworkFailure] if backend is unreachable
  /// - [ServerFailure] if email delivery fails
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepository.sendPasswordResetEmail('user@example.com');
  /// ```
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);

  /// Updates the current user's password using the active Supabase recovery session.
  ///
  /// Called from UpdatePasswordPage after the user clicks the password-reset email
  /// link and the app enters the password-recovery auth state.
  Future<Either<Failure, void>> resetPassword({required String newPassword});

  /// Gets the currently authenticated user.
  ///
  /// Returns cached user if already loaded, or fetches fresh from backend.
  ///
  /// @returns [Either] containing [User] on success or [AuthFailure] on failure
  ///
  /// Returns [AuthFailure] if:
  /// - No user is authenticated
  /// - Session has expired
  /// - Backend error occurs
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepository.getCurrentUser();
  /// ```
  Future<Either<Failure, User?>> getCurrentUser();

  /// Updates the current user's profile information.
  ///
  /// @param displayName Optional new display name
  /// @param avatarUrl Optional new avatar URL
  ///
  /// @returns [Either] containing updated [User] on success or [Failure] on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepository.updateProfile(
  ///   displayName: 'Jane Doe',
  ///   avatarUrl: 'https://example.com/avatar.jpg',
  /// );
  /// ```
  Future<Either<Failure, User>> updateProfile({
    String? displayName,
    String? avatarUrl,
  });

  /// Verifies the user's email address.
  ///
  /// Must be called after user clicks email verification link.
  /// Token is extracted from deep link or provided explicitly.
  ///
  /// @param token The verification token from email link
  ///
  /// @returns [Either] containing void on success or [AuthFailure] on failure
  ///
  /// Example:
  /// ```dart
  /// await authRepository.verifyEmail('verification_token');
  /// ```
  Future<Either<Failure, void>> verifyEmail(String token);

  /// Checks if user is currently authenticated.
  ///
  /// @returns true if valid session exists, false otherwise
  bool isAuthenticated();

  /// Gets current authentication session details.
  ///
  /// @returns Session object or null if not authenticated
  Future<Either<Failure, Map<String, dynamic>?>> getSession();
}
