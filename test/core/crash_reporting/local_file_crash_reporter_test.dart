import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/crash_reporting/local_file_crash_reporter.dart';

void main() {
  late Directory tempDir;
  late LocalFileCrashReporterImpl reporter;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('crash_reporter_test_');
    reporter = LocalFileCrashReporterImpl(
      directoryProvider: () async => tempDir,
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  File logFile() => File('${tempDir.path}/kumo_crash_log.jsonl');

  group('exportFile', () {
    test('returns null when nothing has been recorded yet', () async {
      expect(await reporter.exportFile(), isNull);
    });

    test('returns the file once something has been recorded', () async {
      await reporter.log('hello');
      final file = await reporter.exportFile();
      expect(file, isNotNull);
      expect(file!.path, logFile().path);
    });
  });

  group('recordError', () {
    test('writes a JSON-lines entry with error/stack/reason/fatal', () async {
      await reporter.recordError(
        Exception('boom'),
        StackTrace.fromString('#0 someFunction'),
        reason: 'unit test',
        fatal: true,
      );

      final lines = await logFile().readAsLines();
      expect(lines, hasLength(1));
      final entry = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(entry['type'], 'fatal');
      expect(entry['reason'], 'unit test');
      expect(entry['error'], contains('boom'));
      expect(entry['stackTrace'], contains('someFunction'));
      expect(entry['timestamp'], isNotNull);
    });

    test('fatal: false (the default) is recorded as type "error"', () async {
      await reporter.recordError(Exception('non-fatal'), null);

      final entry =
          jsonDecode((await logFile().readAsLines()).single)
              as Map<String, dynamic>;
      expect(entry['type'], 'error');
    });

    test('omits reason/stackTrace entirely when not given, rather than '
        'writing null', () async {
      await reporter.recordError(Exception('no extras'), null);

      final entry =
          jsonDecode((await logFile().readAsLines()).single)
              as Map<String, dynamic>;
      expect(entry.containsKey('reason'), isFalse);
      expect(entry.containsKey('stackTrace'), isFalse);
    });

    test('never throws even if the underlying write fails', () async {
      // Point at a directory that doesn't exist and won't be created —
      // File.writeAsString into it fails, which must be swallowed, not
      // propagated (this is called from FlutterError.onError/zone error
      // handlers, where a second exception would be actively harmful).
      final brokenReporter = LocalFileCrashReporterImpl(
        directoryProvider: () async =>
            Directory('${tempDir.path}/does/not/exist'),
      );
      await expectLater(
        brokenReporter.recordError(Exception('x'), null),
        completes,
      );
    });
  });

  group('log', () {
    test('writes a "log" type entry with the message', () async {
      await reporter.log('opened chat for trip-123');

      final entry =
          jsonDecode((await logFile().readAsLines()).single)
              as Map<String, dynamic>;
      expect(entry['type'], 'log');
      expect(entry['message'], 'opened chat for trip-123');
    });
  });

  group('size cap', () {
    test('trims the oldest half once the file exceeds ~512KB', () async {
      // Each entry is small; write enough to comfortably cross the cap,
      // then confirm the oldest entries are gone and the newest survive.
      final bigMessage = 'x' * 2000;
      for (var i = 0; i < 400; i++) {
        await reporter.log('$i-$bigMessage');
      }

      final lines = await logFile().readAsLines();
      final length = await logFile().length();
      expect(length, lessThan(600 * 1024), reason: 'should have trimmed');

      final firstEntry = jsonDecode(lines.first) as Map<String, dynamic>;
      final firstIndex = int.parse(
        (firstEntry['message'] as String).split('-').first,
      );
      // The oldest surviving entry should not be message 0 — that's the
      // one furthest back, and trimming drops the oldest half.
      expect(firstIndex, greaterThan(0));

      final lastEntry = jsonDecode(lines.last) as Map<String, dynamic>;
      expect(lastEntry['message'], startsWith('399-'));
    });
  });
}
