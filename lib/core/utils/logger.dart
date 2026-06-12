import 'package:logger/logger.dart';

/// Application-wide logger instance for consistent logging.
///
/// Usage:
/// ```dart
/// AppLogger.info('Message');
/// AppLogger.error('Error message', error: e, stackTrace: st);
/// ```
class AppLogger {
  AppLogger._();
  static final _logger = Logger(
    printer: PrettyPrinter(
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  ); // Private constructor

  /// Log verbose message (lowest priority).
  static void verbose(String message) => _logger.t(message);

  /// Log debug message.
  static void debug(String message) => _logger.d(message);

  /// Log info message.
  static void info(String message) => _logger.i(message);

  /// Log warning message.
  static void warning(String message) => _logger.w(message);

  /// Log error message.
  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  /// Log critical error.
  static void critical(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _logger.f(message, error: error, stackTrace: stackTrace);
}
