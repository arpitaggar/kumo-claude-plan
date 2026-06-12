import 'package:intl/intl.dart';

/// Utility class for formatting dates, currency, and other values.
class Formatters {
  Formatters._(); // Private constructor

  /// Format DateTime to a readable date string (e.g., "Jun 10, 2026").
  static String formatDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  /// Format DateTime to a time string (e.g., "2:30 PM").
  static String formatTime(DateTime dateTime) =>
      DateFormat('h:mm a').format(dateTime);

  /// Format DateTime to full date and time (e.g., "Jun 10, 2026 at 2:30 PM").
  static String formatDateTime(DateTime dateTime) =>
      DateFormat('MMM d, yyyy \'at\' h:mm a').format(dateTime);

  /// Format a currency amount with symbol.
  ///
  /// @param amount The amount to format
  /// @param currencyCode ISO currency code (default: "USD")
  /// @returns Formatted string (e.g., "$1,234.56")
  static String formatCurrency(double amount, [String currencyCode = 'USD']) {
    final formatter = NumberFormat.simpleCurrency(name: currencyCode);
    return formatter.format(amount);
  }

  /// Format a percentage value.
  ///
  /// @param percentage The percentage (0-100)
  /// @returns Formatted string (e.g., "50.0%")
  static String formatPercentage(double percentage) =>
      '${percentage.toStringAsFixed(1)}%';

  /// Format a large number with commas.
  ///
  /// @example 1000000 -> "1,000,000"
  static String formatNumber(num number) {
    final formatter = NumberFormat('#,##0');
    return formatter.format(number);
  }

  /// Format a duration for display.
  ///
  /// @param duration The duration to format
  /// @returns Formatted string (e.g., "2h 30m", "45m", "1d 3h")
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final days = duration.inDays;

    if (days > 0) {
      return '${days}d ${hours % 24}h';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Capitalize first letter of a string.
  ///
  /// @example "hello" -> "Hello"
  static String capitalize(String text) {
    if (text.isEmpty) {
      return text;
    }
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Convert camelCase to Space Separated.
  ///
  /// @example "firstName" -> "First Name"
  static String camelCaseToDisplay(String text) {
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (i == 0) {
        buffer.write(char.toUpperCase());
      } else if (char == char.toUpperCase() && char != char.toLowerCase()) {
        buffer.write(' $char');
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Format a phone number (basic US formatting).
  ///
  /// @example "1234567890" -> "(123) 456-7890"
  static String formatPhoneNumber(String phone) {
    if (phone.length != 10) {
      return phone;
    }
    return '(${phone.substring(0, 3)}) ${phone.substring(3, 6)}-${phone.substring(6)}';
  }

  /// Truncate text with ellipsis.
  ///
  /// @param text The text to truncate
  /// @param maxLength Maximum length before truncation
  /// @returns Truncated string with ellipsis if needed
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength - 3)}...';
  }
}
