import '../../domain/entities/app_notification.dart';

class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.actorId,
    required super.actorName,
    required super.type,
    required super.createdAt,
    super.actorAvatarUrl,
    super.postId,
    super.postTitle,
    super.readAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) =>
      AppNotificationModel(
        id: json['id'] as String,
        actorId: json['actor_id'] as String,
        actorName: json['actor_name'] as String,
        actorAvatarUrl: json['actor_avatar_url'] as String?,
        type: NotificationType.fromWire(json['type'] as String),
        postId: json['post_id'] as String?,
        postTitle: json['post_title'] as String?,
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
