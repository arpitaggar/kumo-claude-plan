import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/trip_segment_repository.dart';

class DeleteTripSegmentUseCase {
  const DeleteTripSegmentUseCase(this._repository);

  final TripSegmentRepository _repository;

  Future<Either<Failure, void>> call(String segmentId) =>
      _repository.deleteSegment(segmentId);
}
