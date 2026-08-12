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

  /// Patches only the segment's cached routed geometry — see
  /// `TripSegmentRemoteDataSource.updateRouteGeometry` for why this isn't a
  /// full-row `updateSegment` call.
  Future<Either<Failure, void>> updateRouteGeometry(
    String segmentId,
    List<(double, double)> geometry,
  );

  /// Clears the segment's cached routed geometry back to null — see
  /// `TripSegmentRemoteDataSource.clearRouteGeometry`.
  Future<Either<Failure, void>> clearRouteGeometry(String segmentId);

  /// Patches only the segment's `isVisible` map-display flag — see
  /// `TripSegmentRemoteDataSource.setVisibility`.
  Future<Either<Failure, void>> setSegmentVisibility(
    String segmentId, {
    required bool isVisible,
  });
}
