import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/post_comment.dart';
import '../repositories/social_repository.dart';

class WatchPostCommentsUseCase {
  const WatchPostCommentsUseCase(this._repository);

  final SocialRepository _repository;

  Stream<Either<Failure, List<PostComment>>> call(String postId) =>
      _repository.watchComments(postId);
}
