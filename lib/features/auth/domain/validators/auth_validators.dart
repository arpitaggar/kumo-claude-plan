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

  /// Client-side mirror of the server-side age gate (see
  /// `docs/supabase_migrations/stage44_age_gate.sql`'s
  /// `enforce_signup_age_gate()` trigger, which is the actual enforcement —
  /// this check exists only to give a fast, friendly error before ever
  /// hitting the network; it is not the security boundary.
  ///
  /// Full Kumo accounts (Captain or Crew) require the holder to be 18+.
  /// Anyone younger participates as a Hitchhiker instead — see
  /// docs/ARCHITECTURE.md.
  ///
  /// @throws ValidationException if [dateOfBirth] is null, in the future, or
  /// implies an age under 18.
  static bool validateAge18Plus(DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      throw ValidationException(message: 'Date of birth is required');
    }
    final now = DateTime.now();
    if (dateOfBirth.isAfter(now)) {
      throw ValidationException(
        message: 'Date of birth cannot be in the future',
      );
    }
    var age = now.year - dateOfBirth.year;
    final hadBirthdayThisYear =
        (now.month > dateOfBirth.month) ||
        (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
    if (!hadBirthdayThisYear) {
      age -= 1;
    }
    if (age < 18) {
      throw ValidationException(
        message: 'Kumo accounts require you to be 18 or older',
      );
    }
    return true;
  }
}
