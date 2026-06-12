import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/travel_itinerary.dart';
import '../repositories/itinerary_repository.dart';

class FetchItinerariesUseCase {
  const FetchItinerariesUseCase(this._repository);

  final ItineraryRepository _repository;

  Future<Either<Failure, List<TravelItinerary>>> call(String userId) =>
      _repository.fetchItineraries(userId);
}
