import '../../domain/entities/app_notification.dart';

/// (title, body) copy for [notification] — shared between the in-app list
/// tile and the foreground local-notification watcher so the two never
/// drift out of sync with each other.
(String title, String body) notificationText(AppNotification notification) =>
    switch (notification.type) {
      NotificationType.like => (
        '${notification.actorName} liked your trip',
        notification.postTitle ?? '',
      ),
      NotificationType.follow => (
        '${notification.actorName} started following you',
        'Tap to view their profile.',
      ),
      NotificationType.newPost => (
        '${notification.actorName} published a new trip',
        notification.postTitle ?? '',
      ),
      NotificationType.comment => (
        '${notification.actorName} commented on your trip',
        notification.postTitle ?? '',
      ),
    };
