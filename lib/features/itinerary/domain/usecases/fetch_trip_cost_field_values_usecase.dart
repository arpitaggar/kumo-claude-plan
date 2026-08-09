import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/trip_cost_field_value.dart';
import '../repositories/trip_cost_field_value_repository.dart';

class FetchTripCostFieldValuesUseCase {
  const FetchTripCostFieldValuesUseCase(this._repository);

  final TripCostFieldValueRepository _repository;

  Future<Either<Failure, List<TripCostFieldValue>>> call(String itineraryId) =>
      _repository.fetchValues(itineraryId);
}
