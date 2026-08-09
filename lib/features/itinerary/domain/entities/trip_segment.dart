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
    this.routeGeometry,
    this.isVisible = true,
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

  /// The real road/footpath route as (lat, lng) points, fetched via
  /// `RoutingService` and cached here — see stage24's migration comment.
  /// Null means "not fetched yet" or "not a routable mode"; the map falls
  /// back to a straight/curved line (`route_map_view.dart`'s `_geoPath`).
  final List<(double, double)>? routeGeometry;

  /// Whether this leg is drawn on the Route tab's map — toggled from the
  /// segment card, e.g. to declutter the map for a leg the traveller
  /// already knows by heart. The segment itself (and its card) still exists
  /// either way; this never deletes anything. See stage25's migration.
  final bool isVisible;

  TripSegment copyWith({
    int? orderIndex,
    TransportMode? mode,
    Waypoint? origin,
    Waypoint? destination,
    DateTime? departureTime,
    DateTime? arrivalTime,
    String? notes,
    List<(double, double)>? routeGeometry,
    bool? isVisible,
  }) => TripSegment(
    id: id,
    itineraryId: itineraryId,
    orderIndex: orderIndex ?? this.orderIndex,
    mode: mode ?? this.mode,
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    departureTime: departureTime ?? this.departureTime,
    arrivalTime: arrivalTime ?? this.arrivalTime,
    notes: notes ?? this.notes,
    routeGeometry: routeGeometry ?? this.routeGeometry,
    isVisible: isVisible ?? this.isVisible,
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
    routeGeometry,
    isVisible,
  ];
}
