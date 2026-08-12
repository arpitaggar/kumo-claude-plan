import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/notifications/data/models/app_notification_model.dart';
import 'package:kumo_claude/features/notifications/domain/entities/app_notification.dart';

void main() {
  group('AppNotificationModel.fromJson', () {
    test('parses a like notification with all fields present', () {
      final model = AppNotificationModel.fromJson(const {
        'id': 'n-1',
        'actor_id': 'actor-1',
        'actor_name': 'Alice',
        'actor_avatar_url': 'https://example.com/a.png',
        'type': 'like',
        'post_id': 'post-1',
        'post_title': 'Tokyo Summer 2026',
        'read_at': '2026-06-02T00:00:00.000Z',
        'created_at': '2026-06-01T00:00:00.000Z',
      });

      expect(model.id, 'n-1');
      expect(model.actorId, 'actor-1');
      expect(model.actorName, 'Alice');
      expect(model.actorAvatarUrl, 'https://example.com/a.png');
      expect(model.type, NotificationType.like);
      expect(model.postId, 'post-1');
      expect(model.postTitle, 'Tokyo Summer 2026');
      expect(model.readAt, DateTime.parse('2026-06-02T00:00:00.000Z'));
      expect(model.isRead, isTrue);
    });

    test('parses a follow notification with no post fields', () {
      final model = AppNotificationModel.fromJson(const {
        'id': 'n-2',
        'actor_id': 'actor-2',
        'actor_name': 'Bob',
        'actor_avatar_url': null,
        'type': 'follow',
        'post_id': null,
        'post_title': null,
        'read_at': null,
        'created_at': '2026-06-01T00:00:00.000Z',
      });

      expect(model.type, NotificationType.follow);
      expect(model.postId, isNull);
      expect(model.postTitle, isNull);
      expect(model.actorAvatarUrl, isNull);
      expect(model.isRead, isFalse);
    });

    test('parses new_post type from its wire representation', () {
      final model = AppNotificationModel.fromJson(const {
        'id': 'n-3',
        'actor_id': 'actor-3',
        'actor_name': 'Carol',
        'type': 'new_post',
        'post_id': 'post-3',
        'post_title': 'Rome Autumn',
        'created_at': '2026-06-01T00:00:00.000Z',
      });

      expect(model.type, NotificationType.newPost);
    });
  });
}
