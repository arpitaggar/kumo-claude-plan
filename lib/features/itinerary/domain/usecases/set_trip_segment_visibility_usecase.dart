import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/trip_segment_repository.dart';

class SetTripSegmentVisibilityUseCase {
  const SetTripSegmentVisibilityUseCase(this._repository);

  final TripSegmentRepository _repository;

  Future<Either<Failure, void>> call(String segmentId, bool isVisible) =>
      _repository.setSegmentVisibility(segmentId, isVisible);
}
