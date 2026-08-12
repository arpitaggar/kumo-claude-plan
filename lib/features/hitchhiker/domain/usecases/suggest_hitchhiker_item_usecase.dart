import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/hitchhiker_access_repository.dart';

class SuggestHitchhikerItemUseCase {
  const SuggestHitchhikerItemUseCase(this._repository);

  final HitchhikerAccessRepository _repository;

  Future<Either<Failure, void>> call({
    required String token,
    required String title,
    String? description,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return const Left(ValidationFailure('A title is required'));
    }
    if (trimmedTitle.length > 200) {
      return const Left(
        ValidationFailure('Title must be 200 characters or fewer'),
      );
    }
    return _repository.suggestItem(
      token: token,
      title: trimmedTitle,
      description: description,
    );
  }
}
