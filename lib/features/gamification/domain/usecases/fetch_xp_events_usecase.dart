import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/xp_event.dart';
import '../repositories/gamification_repository.dart';

class FetchXpEventsUseCase {
  const FetchXpEventsUseCase(this._repository);

  final GamificationRepository _repository;

  Future<Either<Failure, List<XpEvent>>> call(String userId) =>
      _repository.fetchXpEvents(userId);
}
