import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/social_repository.dart';

class AddPostCommentUseCase {
  const AddPostCommentUseCase(this._repository);

  final SocialRepository _repository;

  Future<Either<Failure, void>> call({
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
    String? authorAvatarUrl,
  }) => _repository.addComment(
    postId: postId,
    authorId: authorId,
    authorName: authorName,
    content: content,
    authorAvatarUrl: authorAvatarUrl,
  );
}
