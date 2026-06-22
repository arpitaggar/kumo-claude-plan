import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../repositories/discover_repository.dart';

class FetchPublicItinerariesUseCase {
  const FetchPublicItinerariesUseCase(this._repository);

  final DiscoverRepository _repository;

  Future<Either<Failure, List<TravelItinerary>>> call({String? query}) =>
      _repository.fetchPublicItineraries(query: query);
}
