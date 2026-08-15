/// Records uncaught errors and breadcrumb-style log lines so they can be
/// inspected after the fact — the gap that made the 2026-08-15 "Realtime
/// subscribe exception went away after restarting the app" bug report
/// undiagnosable without the user manually reproducing it and reading a
/// stack trace back over chat. `AppLogger` (`core/utils/logger.dart`) only
/// prints to the console, which nobody is tailing on a real user's phone.
///
/// Deliberately a thin, backend-agnostic interface — [wire it up once in
/// `main.dart`](../../main.dart) via `crashReporterProvider`, and every call
/// site (`FlutterError.onError`, `PlatformDispatcher.instance.onError`, a
/// try/catch anywhere in the app) goes through this, not a concrete
/// implementation. `LocalFileCrashReporterImpl` is today's implementation —
/// swapping to Firebase Crashlytics or Sentry later is a one-line change to
/// `crashReporterProvider`'s override, nothing else in the app changes.
abstract class CrashReporter {
  /// Records an error. Implementations must never let recording itself
  /// throw or block — this is called from error zones and
  /// `FlutterError.onError`, where a second exception would be silently
  /// swallowed at best.
  ///
  /// [reason] is a short label for where this was caught (e.g. the
  /// function/zone name), not the error message itself. [fatal] marks an
  /// error the app couldn't recover from without external intervention
  /// (crashed a screen, corrupted state) vs. one that was caught and
  /// handled gracefully but is still worth a record.
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  });

  /// A short breadcrumb, timestamped alongside errors — e.g. "opened chat
  /// for trip X" — so a later error record has some context for what led
  /// up to it, not just the error itself.
  Future<void> log(String message);
}
