import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../entities/travel_itinerary.dart';
import '../repositories/itinerary_repository.dart';

class UpdateItineraryUseCase {
  const UpdateItineraryUseCase(this._repository);

  final ItineraryRepository _repository;

  Future<Either<Failure, TravelItinerary>> call(
    TravelItinerary itinerary,
  ) async {
    try {
      Validators.validateNonEmpty(itinerary.title, 'Title');
      Validators.validateDateRange(itinerary.startDate, itinerary.endDate);
      Validators.validateAmount(itinerary.totalBudget, 'Budget');
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    }

    return _repository.updateItinerary(
      itinerary.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }
}
