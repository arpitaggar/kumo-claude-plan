import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/trip_segment.dart';
import '../repositories/trip_segment_repository.dart';

class UpdateTripSegmentUseCase {
  const UpdateTripSegmentUseCase(this._repository);

  final TripSegmentRepository _repository;

  Future<Either<Failure, TripSegment>> call(TripSegment segment) =>
      _repository.updateSegment(segment);
}
