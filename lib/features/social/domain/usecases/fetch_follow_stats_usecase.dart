import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/follow_stats.dart';
import '../repositories/follow_repository.dart';

class FetchFollowStatsUseCase {
  const FetchFollowStatsUseCase(this._repository);

  final FollowRepository _repository;

  Future<Either<Failure, FollowStats>> call({
    required String userId,
    required String currentUserId,
  }) => _repository.fetchFollowStats(
    userId: userId,
    currentUserId: currentUserId,
  );
}
