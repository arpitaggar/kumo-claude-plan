import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/social_repository.dart';

class DeletePostCommentUseCase {
  const DeletePostCommentUseCase(this._repository);

  final SocialRepository _repository;

  Future<Either<Failure, void>> call(String commentId) =>
      _repository.deleteComment(commentId);
}
