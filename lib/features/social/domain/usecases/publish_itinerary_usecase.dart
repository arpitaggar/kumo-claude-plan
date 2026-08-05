import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../../itinerary/domain/entities/trip_segment.dart';
import '../entities/itinerary_post.dart';
import '../repositories/social_repository.dart';

class PublishItineraryUseCase {
  const PublishItineraryUseCase(this._repository);

  final SocialRepository _repository;

  Future<Either<Failure, ItineraryPost>> call({
    required TravelItinerary itinerary,
    required List<TripSegment> segments,
    required String authorName,
    String? authorAvatarUrl,
  }) => _repository.publishItinerary(
    itinerary: itinerary,
    segments: segments,
    authorName: authorName,
    authorAvatarUrl: authorAvatarUrl,
  );
}
