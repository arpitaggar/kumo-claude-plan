import 'package:equatable/equatable.dart';

/// Mirrors the `type` check constraint on `public.notifications`
/// (`stage37_social_notifications.sql`, widened by `stage38_post_comments.sql`
/// to add `comment`).
enum NotificationType {
  like,
  follow,
  newPost,
  comment;

  static NotificationType fromWire(String value) => switch (value) {
    'like' => NotificationType.like,
    'follow' => NotificationType.follow,
    'new_post' => NotificationType.newPost,
    'comment' => NotificationType.comment,
    _ => throw ArgumentError('Unknown notification type: $value'),
  };
}

/// One row in the current user's activity feed — someone liked or forked
/// their post, followed them, or a followed account published a new trip.
///
/// Every row is server-written (see the trigger functions in
/// `stage37_social_notifications.sql`) — the client never inserts one
/// directly, only reads and marks-read.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.type,
    required this.createdAt,
    this.actorAvatarUrl,
    this.postId,
    this.postTitle,
    this.readAt,
  });

  final String id;
  final String actorId;

  /// Denormalised at insert time — still correct even if the actor later
  /// renames themselves. See `AppNotification` doc.
  final String actorName;
  final String? actorAvatarUrl;

  final NotificationType type;

  /// Set for [NotificationType.like]/[NotificationType.newPost]; null for
  /// [NotificationType.follow].
  final String? postId;
  final String? postTitle;

  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  @override
  List<Object?> get props => [
    id,
    actorId,
    actorName,
    actorAvatarUrl,
    type,
    postId,
    postTitle,
    readAt,
    createdAt,
  ];
}
