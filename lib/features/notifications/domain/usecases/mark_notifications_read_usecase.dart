import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/notifications_repository.dart';

class MarkNotificationsReadUseCase {
  const MarkNotificationsReadUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<Either<Failure, void>> call(String userId) =>
      _repository.markAllRead(userId);
}
