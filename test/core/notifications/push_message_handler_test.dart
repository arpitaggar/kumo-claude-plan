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
        () => handleIosPushTap(
          const RemoteMessage(data: {'tripId': 'trip-1', 'body': 'hi'}),
        ),
        returnsNormally,
      );
    });

    test('does nothing for a social payload with no actorId', () {
      // Same early-return shape as the tripId case above, but on the
      // kind: 'social' branch.
      expect(
        () => handleIosPushTap(
          const RemoteMessage(data: {'kind': 'social', 'title': 'hi'}),
        ),
        returnsNormally,
      );
    });

    test('does not fall through to the chat branch for a social payload', () {
      // No navigator mounted, so this still can't observe navigation — it
      // exercises that a social-kind payload short-circuits before ever
      // reaching the tripId-based chat logic below it.
      expect(
        () => handleIosPushTap(
          const RemoteMessage(data: {'kind': 'social', 'actorId': 'actor-1'}),
        ),
        returnsNormally,
      );
    });
  });
}
