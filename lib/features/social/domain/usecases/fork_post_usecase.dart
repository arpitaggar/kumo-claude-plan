import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../repositories/social_repository.dart';

/// Creates a private, independent itinerary for the current user from a
/// published post's snapshot ("use this itinerary").
class ForkPostUseCase {
  const ForkPostUseCase(this._repository);

  final SocialRepository _repository;

  Future<Either<Failure, TravelItinerary>> call({
    required String postId,
    required String newOwnerId,
    required String newOwnerName,
  }) => _repository.forkPost(
    postId: postId,
    newOwnerId: newOwnerId,
    newOwnerName: newOwnerName,
  );
}
