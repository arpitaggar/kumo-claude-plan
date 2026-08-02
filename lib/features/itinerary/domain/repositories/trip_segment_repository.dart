import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/trip_segment.dart';

abstract class TripSegmentRepository {
  Stream<Either<Failure, List<TripSegment>>> watchSegments(String itineraryId);

  Future<Either<Failure, TripSegment>> addSegment(TripSegment segment);

  Future<Either<Failure, TripSegment>> updateSegment(TripSegment segment);

  Future<Either<Failure, void>> deleteSegment(String segmentId);

  /// Writes the full, already-renumbered segment list in one batched call.
  Future<Either<Failure, void>> reorderSegments(
    String itineraryId,
    List<TripSegment> reordered,
  );
}
