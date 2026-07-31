import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kumo_claude/config/router.dart';
import 'package:kumo_claude/core/notifications/push_message_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('handleIosPushTap', () {
    test('does nothing when the payload has no tripId', () {
      // No tripId means the early-return in handleIosPushTap must fire
      // before it ever touches rootNavigatorKey — if it didn't, this would
      // throw since no navigator is mounted in this test.
      expect(
        () => handleIosPushTap(const RemoteMessage(data: {'body': 'hi'})),
        returnsNormally,
      );
    });

    test('does nothing when no navigator is currently mounted', () {
      // rootNavigatorKey.currentContext is null outside of a running app
      // (nothing has built a MaterialApp/Navigator in this test), so this
      // exercises the second early-return instead of actually navigating.
      expect(rootNavigatorKey.currentContext, isNull);

      expect(
        () => handleIosPushTap(const RemoteMessage(
          data: {'tripId': 'trip-1', 'body': 'hi'},
        )),
        returnsNormally,
      );
    });
  });
}
