import '../../../../core/error/exception.dart';

/// Auth-domain validation rules — email format and password strength are
/// genuinely auth concerns, unlike the generic cross-feature checks
/// (non-empty, date range, amount, ...) that stay in `core/utils/validators.dart`.
/// Split out per docs/SOLID_AUDIT.md's "Validators grab-bag" finding.
class AuthValidators {
  AuthValidators._(); // Private constructor to prevent instantiation

  /// Validates email format using a simplified regex.
  ///
  /// @param email The email address to validate
  /// @returns true if valid, false otherwise
  /// @throws ValidationException if email is empty or null
  static bool validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      throw ValidationException(message: 'Email cannot be empty');
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validates password strength.
  ///
  /// Requirements:
  /// - Minimum 8 characters
  /// - At least one uppercase letter (optional for MVP)
  /// - At least one number (optional for MVP)
  ///
  /// @param password The password to validate
  /// @returns true if valid, false otherwise
  /// @throws ValidationException if password is empty or null
  static bool validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      throw ValidationException(message: 'Password cannot be empty');
    }
    if (password.length < 8) {
      throw ValidationException(
        message: 'Password must be at least 8 characters',
      );
    }
    return true;
  }
}
