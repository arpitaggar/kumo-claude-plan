import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';

abstract class DiscoverRepository {
  Future<Either<Failure, List<TravelItinerary>>> fetchPublicItineraries({
    String? query,
  });

  Future<Either<Failure, TravelItinerary>> cloneItinerary({
    required String itineraryId,
    required String newOwnerId,
    required String newOwnerName,
  });
}
