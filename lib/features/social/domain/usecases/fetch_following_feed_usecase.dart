import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/itinerary_post.dart';
import '../repositories/social_repository.dart';

class FetchFollowingFeedUseCase {
  const FetchFollowingFeedUseCase(this._repository);

  final SocialRepository _repository;

  Future<Either<Failure, List<ItineraryPost>>> call({
    required String currentUserId,
  }) => _repository.fetchFeed(currentUserId: currentUserId);
}
