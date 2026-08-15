import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'crash_reporter.dart';

/// Implemented only by a [CrashReporter] that keeps a local, user-shareable
/// artifact — not every backend has one (a remote-only backend like Sentry
/// or Firebase Crashlytics wouldn't implement this), so this is
/// deliberately not part of [CrashReporter] itself. Callers that want to
/// offer a "share debug log" action (see `profile_page.dart`) check for
/// this via `reporter is ExportableCrashLog`.
abstract class ExportableCrashLog {
  /// The log file, or null if nothing has been recorded yet.
  Future<File?> exportFile();
}

/// Appends JSON-lines entries to a capped local file — today's
/// [CrashReporter] implementation. No dashboard, no network call, nothing
/// to configure; the tradeoff is that getting a record out requires the
/// user to share the file (see `ExportableCrashLog`/`profile_page.dart`)
/// rather than it showing up automatically wherever a real backend would
/// surface it.
class LocalFileCrashReporterImpl implements CrashReporter, ExportableCrashLog {
  /// [directoryProvider] defaults to the real platform directory; tests
  /// inject `Directory.systemTemp`-based fakes instead, since
  /// `path_provider` needs a platform channel with no in-memory fake
  /// shipped for it (unlike `flutter_secure_storage`, see
  /// `test/helpers/test_helpers.dart`).
  LocalFileCrashReporterImpl({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  /// Caps the file at roughly this many bytes by dropping the oldest lines
  /// once exceeded — an app that's been installed for months shouldn't
  /// accumulate an unbounded log on a real user's device.
  static const _maxBytes = 512 * 1024;

  Future<File> _file() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/kumo_crash_log.jsonl');
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) => _appendSafely({
    'timestamp': DateTime.now().toIso8601String(),
    'type': fatal ? 'fatal' : 'error',
    'reason': ?reason,
    'error': error.toString(),
    'stackTrace': ?stackTrace?.toString(),
  });

  @override
  Future<void> log(String message) => _appendSafely({
    'timestamp': DateTime.now().toIso8601String(),
    'type': 'log',
    'message': message,
  });

  @override
  Future<File?> exportFile() async {
    final file = await _file();
    return file.existsSync() ? file : null;
  }

  /// Never lets a failure here propagate — this is called from error zones
  /// (`FlutterError.onError`, `runZonedGuarded`'s handler), where an
  /// exception thrown while *recording* an exception would just be
  /// silently dropped by the zone anyway, or worse, mask the original
  /// error. A crash reporter that can itself crash defeats the point.
  Future<void> _appendSafely(Map<String, Object?> entry) async {
    try {
      final file = await _file();
      await file.writeAsString(
        '${jsonEncode(entry)}\n',
        mode: FileMode.append,
        flush: true,
      );
      await _trimIfNeeded(file);
    } catch (_) {
      // Deliberately swallowed — see doc comment above.
    }
  }

  Future<void> _trimIfNeeded(File file) async {
    final length = await file.length();
    if (length <= _maxBytes) {
      return;
    }
    // Drop the oldest half rather than trimming to exactly the cap on
    // every single write once near the limit — cheaper amortized cost for
    // a log that's being appended to frequently.
    final lines = await file.readAsLines();
    final kept = lines.sublist(lines.length ~/ 2);
    await file.writeAsString('${kept.join('\n')}\n');
  }
}
