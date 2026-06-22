import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../repositories/discover_repository.dart';

class CloneItineraryUseCase {
  const CloneItineraryUseCase(this._repository);

  final DiscoverRepository _repository;

  Future<Either<Failure, TravelItinerary>> call({
    required String itineraryId,
    required String newOwnerId,
    required String newOwnerName,
  }) => _repository.cloneItinerary(
        itineraryId: itineraryId,
        newOwnerId: newOwnerId,
        newOwnerName: newOwnerName,
      );
}
