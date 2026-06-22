import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/rating_repository.dart';

class DeleteRatingUseCase {
  const DeleteRatingUseCase(this._repository);

  final RatingRepository _repository;

  Future<Either<Failure, void>> call(String ratingId) =>
      _repository.deleteRating(ratingId);
}
