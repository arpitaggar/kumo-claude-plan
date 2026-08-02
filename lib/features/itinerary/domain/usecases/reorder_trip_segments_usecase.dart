import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/trip_segment.dart';
import '../repositories/trip_segment_repository.dart';

class ReorderTripSegmentsUseCase {
  const ReorderTripSegmentsUseCase(this._repository);

  final TripSegmentRepository _repository;

  /// Renumbers [segments] to 0..n-1 (preserving the given order) and writes
  /// the whole list back in one batched call. Used for every insert/delete/
  /// reorder mutation rather than shifting individual order_index values —
  /// simpler to reason about and self-healing at this scale (a handful to a
  /// few dozen segments per trip).
  Future<Either<Failure, void>> call(
    String itineraryId,
    List<TripSegment> segments,
  ) {
    final renumbered = [
      for (var i = 0; i < segments.length; i++)
        segments[i].copyWith(orderIndex: i),
    ];
    return _repository.reorderSegments(itineraryId, renumbered);
  }
}
