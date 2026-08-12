import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kumo_claude/core/notifications/notification_tap_events.dart';
import 'package:kumo_claude/core/notifications/push_message_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('handleIosPushTap', () {
    test('does nothing when the payload has no tripId', () async {
      final events = <NotificationTapEvent>[];
      final sub = notificationTaps.listen(events.add);
      addTearDown(sub.cancel);

      handleIosPushTap(const RemoteMessage(data: {'body': 'hi'}));
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('emits a chat tap event with the tripId', () async {
      final events = <NotificationTapEvent>[];
      final sub = notificationTaps.listen(events.add);
      addTearDown(sub.cancel);

      handleIosPushTap(
        const RemoteMessage(data: {'tripId': 'trip-1', 'body': 'hi'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.kind, NotificationTapKind.chat);
      expect(events.single.id, 'trip-1');
    });

    test('does nothing for a social payload with no actorId', () async {
      final events = <NotificationTapEvent>[];
      final sub = notificationTaps.listen(events.add);
      addTearDown(sub.cancel);

      handleIosPushTap(
        const RemoteMessage(data: {'kind': 'social', 'title': 'hi'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test(
      'emits a social tap event and does not fall through to the chat branch',
      () async {
        final events = <NotificationTapEvent>[];
        final sub = notificationTaps.listen(events.add);
        addTearDown(sub.cancel);

        handleIosPushTap(
          const RemoteMessage(data: {'kind': 'social', 'actorId': 'actor-1'}),
        );
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.single.kind, NotificationTapKind.social);
        expect(events.single.id, 'actor-1');
      },
    );
  });
}
