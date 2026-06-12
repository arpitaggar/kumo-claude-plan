import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/travel_itinerary.dart';
import '../repositories/itinerary_repository.dart';

class FetchItineraryUseCase {
  const FetchItineraryUseCase(this._repository);

  final ItineraryRepository _repository;

  Future<Either<Failure, TravelItinerary>> call(String id) =>
      _repository.fetchItinerary(id);
}
