import 'package:intl/intl.dart';

/// Generic, cross-feature display formatters — date/currency formatting has
/// no single "owning" domain (used across itinerary, expense, chat, ...),
/// so this stays a shared core utility rather than moving under one feature.
///
/// Previously also carried `formatTime`/`formatPercentage`/`formatNumber`/
/// `formatDuration`/`capitalize`/`camelCaseToDisplay`/`truncate`, and a
/// hardcoded US-only `formatPhoneNumber` — none were called anywhere in the
/// app and none had test coverage; removed rather than kept as unused,
/// untested surface (see docs/SOLID_AUDIT.md's "Validators/Formatters
/// grab-bag" finding, which named the phone formatter specifically).
class Formatters {
  Formatters._(); // Private constructor

  /// Format DateTime to a readable date string (e.g., "Jun 10, 2026").
  static String formatDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

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
}
