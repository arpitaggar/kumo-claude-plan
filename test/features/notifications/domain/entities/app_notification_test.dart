import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/notifications/domain/entities/app_notification.dart';

void main() {
  group('NotificationType.fromWire', () {
    test('maps like/follow/new_post to the matching enum value', () {
      expect(NotificationType.fromWire('like'), NotificationType.like);
      expect(NotificationType.fromWire('follow'), NotificationType.follow);
      expect(NotificationType.fromWire('new_post'), NotificationType.newPost);
    });

    test('throws for an unrecognized wire value', () {
      expect(() => NotificationType.fromWire('bogus'), throwsArgumentError);
    });
  });

  group('AppNotification.isRead', () {
    AppNotification build({DateTime? readAt}) => AppNotification(
      id: 'n-1',
      actorId: 'actor-1',
      actorName: 'Alice',
      type: NotificationType.follow,
      createdAt: DateTime.utc(2026),
      readAt: readAt,
    );

    test('is false when readAt is null', () {
      expect(build().isRead, isFalse);
    });

    test('is true when readAt is set', () {
      expect(build(readAt: DateTime.utc(2026, 1, 2)).isRead, isTrue);
    });
  });
}
