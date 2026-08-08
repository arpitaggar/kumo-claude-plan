import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/trip_cost_field_value_repository.dart';

class SetTripCostFieldValuesUseCase {
  const SetTripCostFieldValuesUseCase(this._repository);

  final TripCostFieldValueRepository _repository;

  Future<Either<Failure, void>> call(
    String itineraryId,
    Map<String, String> fieldIdToOptionId,
  ) =>
      _repository.setValues(itineraryId, fieldIdToOptionId);
}
