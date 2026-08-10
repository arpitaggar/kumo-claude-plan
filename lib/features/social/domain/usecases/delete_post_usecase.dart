import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/social_repository.dart';

class DeletePostUseCase {
  const DeletePostUseCase(this._repository);

  final SocialRepository _repository;

  Future<Either<Failure, void>> call(String postId) =>
      _repository.deletePost(postId);
}
