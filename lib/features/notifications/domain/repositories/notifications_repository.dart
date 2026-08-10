import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/app_notification.dart';

abstract class NotificationsRepository {
  /// Live view of [userId]'s most recent notifications, newest first.
  /// Bounded (see the datasource impl) — this backs both the activity feed
  /// page and the unread badge/foreground-push watcher, not a fully
  /// paginated history.
  Stream<Either<Failure, List<AppNotification>>> watchNotifications(
    String userId,
  );

  /// Marks every unread notification for [userId] as read.
  Future<Either<Failure, void>> markAllRead(String userId);
}
