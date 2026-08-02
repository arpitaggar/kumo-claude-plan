import 'package:equatable/equatable.dart';

import 'transport_mode.dart';
import 'waypoint.dart';

/// One leg of a trip's route (e.g. "Flight: Munich -> Bangkok").
///
/// [origin]/[destination] are denormalised full waypoints rather than a
/// shared/linked waypoint id — editing this segment's destination does NOT
/// retroactively update the next segment's origin. Continuity between
/// consecutive segments is a UI convenience at creation time only (see
/// "continue trip from here" in the Route tab), not an enforced invariant.
class TripSegment extends Equatable {
  const TripSegment({
    required this.id,
    required this.itineraryId,
    required this.orderIndex,
    required this.mode,
    required this.origin,
    required this.destination,
    this.departureTime,
    this.arrivalTime,
    this.notes,
  });

  final String id;
  final String itineraryId;
  final int orderIndex;
  final TransportMode mode;
  final Waypoint origin;
  final Waypoint destination;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final String? notes;

  TripSegment copyWith({
    int? orderIndex,
    TransportMode? mode,
    Waypoint? origin,
    Waypoint? destination,
    DateTime? departureTime,
    DateTime? arrivalTime,
    String? notes,
  }) =>
      TripSegment(
        id: id,
        itineraryId: itineraryId,
        orderIndex: orderIndex ?? this.orderIndex,
        mode: mode ?? this.mode,
        origin: origin ?? this.origin,
        destination: destination ?? this.destination,
        departureTime: departureTime ?? this.departureTime,
        arrivalTime: arrivalTime ?? this.arrivalTime,
        notes: notes ?? this.notes,
      );

  @override
  List<Object?> get props => [
        id,
        itineraryId,
        orderIndex,
        mode,
        origin,
        destination,
        departureTime,
        arrivalTime,
        notes,
      ];
}
