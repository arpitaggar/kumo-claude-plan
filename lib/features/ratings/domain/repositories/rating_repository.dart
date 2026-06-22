import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/rating.dart';

abstract class RatingRepository {
  Stream<Either<Failure, List<Rating>>> watchRatings(String itineraryId);
  Future<Either<Failure, Rating>> addRating(Rating rating);
  Future<Either<Failure, void>> deleteRating(String ratingId);
}
