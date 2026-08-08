import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/trip_cost_field_value.dart';

abstract class TripCostFieldValueRepository {
  Future<Either<Failure, List<TripCostFieldValue>>> fetchValues(
    String itineraryId,
  );

  /// Upserts one row per entry in [fieldIdToOptionId] — a single batched
  /// call, not one per field.
  Future<Either<Failure, void>> setValues(
    String itineraryId,
    Map<String, String> fieldIdToOptionId,
  );
}
