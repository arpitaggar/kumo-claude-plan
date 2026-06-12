import '../error/exception.dart';

/// Utility class for common validation operations.
///
/// Provides static methods for validating email, password, URLs,
/// currency codes, and other domain-specific inputs.
class Validators {
  Validators._(); // Private constructor to prevent instantiation

  /// Validates email format using a simplified regex.
  ///
  /// @param email The email address to validate
  /// @returns true if valid, false otherwise
  /// @throws ValidationException if email is empty or null
  ///
  /// Example:
  /// ```dart
  /// Validators.validateEmail('user@example.com'); // true
  /// Validators.validateEmail('invalid-email'); // false
  /// ```
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

  /// Validates ISO 4217 currency code.
  ///
  /// @param currencyCode The currency code (e.g., "USD", "JPY")
  /// @returns true if valid, false otherwise
  ///
  /// Example:
  /// ```dart
  /// Validators.validateCurrencyCode('USD'); // true
  /// Validators.validateCurrencyCode('INVALID'); // false
  /// ```
  static bool validateCurrencyCode(String? currencyCode) {
    if (currencyCode == null || currencyCode.isEmpty) {
      return false;
    }
    const validCodes = [
      'USD',
      'EUR',
      'GBP',
      'JPY',
      'CNY',
      'INR',
      'AUD',
      'CAD',
      'CHF',
      'SEK',
      'NZD',
      'SGD',
      'HKD',
      'NOK',
      'KRW',
      'TRY',
      'RUB',
      'INR',
      'ZAR',
      'MXN',
    ];
    return validCodes.contains(currencyCode.toUpperCase());
  }

  /// Validates that an amount is non-negative.
  ///
  /// @param amount The amount to validate
  /// @param fieldName Name of the field for error messages
  /// @throws ValidationException if amount is negative
  static void validateAmount(double amount, [String fieldName = 'Amount']) {
    if (amount < 0) {
      throw ValidationException(message: '$fieldName cannot be negative');
    }
  }

  /// Validates that a percentage is between 0 and 100.
  ///
  /// @param percentage The percentage to validate
  /// @throws ValidationException if not between 0-100
  static void validatePercentage(double percentage) {
    if (percentage < 0 || percentage > 100) {
      throw ValidationException(
        message: 'Percentage must be between 0 and 100',
      );
    }
  }

  /// Validates that a date range is valid (start before end).
  ///
  /// @param startDate The start date
  /// @param endDate The end date
  /// @throws ValidationException if startDate is after endDate
  static void validateDateRange(DateTime startDate, DateTime endDate) {
    if (startDate.isAfter(endDate)) {
      throw ValidationException(message: 'Start date must be before end date');
    }
  }

  /// Validates a non-empty string.
  ///
  /// @param value The string to validate
  /// @param fieldName Name of the field for error messages
  /// @throws ValidationException if value is empty
  static void validateNonEmpty(String? value, [String fieldName = 'Field']) {
    if (value == null || value.trim().isEmpty) {
      throw ValidationException(message: '$fieldName cannot be empty');
    }
  }

  /// Validates that a list is not empty.
  ///
  /// @param list The list to validate
  /// @param fieldName Name of the field for error messages
  /// @throws ValidationException if list is empty
  static void validateNonEmptyList<T>(
    List<T>? list, [
    String fieldName = 'List',
  ]) {
    if (list == null || list.isEmpty) {
      throw ValidationException(message: '$fieldName cannot be empty');
    }
  }

  /// Validates that a UUID is valid.
  ///
  /// @param uuid The UUID to validate
  /// @returns true if valid UUID format, false otherwise
  static bool validateUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) {
      return false;
    }
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(uuid);
  }
}
