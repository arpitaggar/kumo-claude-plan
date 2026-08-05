import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/social_repository.dart';

class ToggleLikeUseCase {
  const ToggleLikeUseCase(this._repository);

  final SocialRepository _repository;

  Future<Either<Failure, void>> call({
    required String postId,
    required String userId,
    required bool like,
  }) => _repository.toggleLike(postId: postId, userId: userId, like: like);
}
