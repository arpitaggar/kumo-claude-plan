import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/follow_repository.dart';

class ToggleFollowUseCase {
  const ToggleFollowUseCase(this._repository);

  final FollowRepository _repository;

  Future<Either<Failure, void>> call({
    required String followerId,
    required String followeeId,
    required bool follow,
  }) => _repository.toggleFollow(
    followerId: followerId,
    followeeId: followeeId,
    follow: follow,
  );
}
