import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/app_notification.dart';
import '../repositories/notifications_repository.dart';

class WatchNotificationsUseCase {
  const WatchNotificationsUseCase(this._repository);

  final NotificationsRepository _repository;

  Stream<Either<Failure, List<AppNotification>>> call(String userId) =>
      _repository.watchNotifications(userId);
}
