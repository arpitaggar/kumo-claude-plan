import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/itinerary_repository.dart';

class DeleteItineraryUseCase {
  const DeleteItineraryUseCase(this._repository);

  final ItineraryRepository _repository;

  Future<Either<Failure, void>> call(String id) =>
      _repository.deleteItinerary(id);
}
