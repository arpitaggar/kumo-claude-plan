import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../entities/rating.dart';
import '../repositories/rating_repository.dart';

class AddRatingUseCase {
  const AddRatingUseCase(this._repository);

  final RatingRepository _repository;

  Future<Either<Failure, Rating>> call({
    required String itineraryId,
    required String targetName,
    required int stars,
    required String userId,
    required String userName,
    String? itemId,
    String? comment,
  }) {
    final rating = Rating(
      id: const Uuid().v4(),
      itineraryId: itineraryId,
      itemId: itemId,
      targetName: targetName,
      stars: stars.clamp(1, 5),
      comment: comment?.trim().isEmpty == true ? null : comment?.trim(),
      userId: userId,
      userName: userName,
      createdAt: DateTime.now().toUtc(),
    );
    return _repository.addRating(rating);
  }
}
