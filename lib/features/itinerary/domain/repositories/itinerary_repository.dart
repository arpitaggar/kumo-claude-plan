import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/travel_itinerary.dart';

abstract class ItineraryRepository {
  /// Fetches all itineraries owned by or shared with [userId].
  Future<Either<Failure, List<TravelItinerary>>> fetchItineraries(String userId);

  /// Fetches a single itinerary by [id].
  Future<Either<Failure, TravelItinerary>> fetchItinerary(String id);

  /// Creates a new itinerary and returns the persisted entity.
  Future<Either<Failure, TravelItinerary>> createItinerary(
    TravelItinerary itinerary,
  );

  /// Updates an existing itinerary and returns the updated entity.
  Future<Either<Failure, TravelItinerary>> updateItinerary(
    TravelItinerary itinerary,
  );

  /// Deletes an itinerary by [id].
  Future<Either<Failure, void>> deleteItinerary(String id);

  /// Streams real-time updates for a single itinerary.
  Stream<Either<Failure, TravelItinerary>> watchItinerary(String id);
}
