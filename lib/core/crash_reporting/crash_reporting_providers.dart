import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crash_reporter.dart';

/// The single switch point mentioned in `crash_reporter.dart`'s doc comment
/// — overridden in `main.dart` with the exact instance wired into
/// `FlutterError.onError`/`PlatformDispatcher.instance.onError`, so every
/// consumer (this provider) and the top-level error handlers (which run
/// before any `ProviderScope` exists, so can't use `ref`) share one
/// reporter rather than two independent ones.
///
/// To switch backends later (Sentry, Firebase Crashlytics): implement
/// `CrashReporter` for that backend and change the instance created in
/// `main.dart` — this provider itself never needs to change.
final crashReporterProvider = Provider<CrashReporter>(
  (ref) => throw UnimplementedError(
    'crashReporterProvider must be overridden in main.dart with the same '
    'instance passed to FlutterError.onError/PlatformDispatcher.onError.',
  ),
);
