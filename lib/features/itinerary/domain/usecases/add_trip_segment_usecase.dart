import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../entities/transport_mode.dart';
import '../entities/trip_segment.dart';
import '../entities/waypoint.dart';
import '../repositories/trip_segment_repository.dart';

class AddTripSegmentUseCase {
  const AddTripSegmentUseCase(this._repository);

  final TripSegmentRepository _repository;

  Future<Either<Failure, TripSegment>> call({
    required String itineraryId,
    required int orderIndex,
    required TransportMode mode,
    required Waypoint origin,
    required Waypoint destination,
    DateTime? departureTime,
    DateTime? arrivalTime,
    String? notes,
  }) {
    final segment = TripSegment(
      id: const Uuid().v4(),
      itineraryId: itineraryId,
      orderIndex: orderIndex,
      mode: mode,
      origin: origin,
      destination: destination,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      notes: notes,
    );
    return _repository.addSegment(segment);
  }
}
