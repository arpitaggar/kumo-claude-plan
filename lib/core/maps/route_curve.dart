import 'dart:math';

import '../../features/itinerary/domain/entities/trip_segment.dart';
import '../../features/itinerary/domain/entities/waypoint.dart';

// Waypoints within this many degrees of each other (~5-6 km at the equator)
// are treated as "the same place" for to-and-fro detection — independently
// geocoding the same city twice (once per direction) doesn't always return
// bit-identical coordinates.
const samePlaceEpsilonDegrees = 0.05;

bool sameWaypoint(Waypoint a, Waypoint b) =>
    (a.latitude - b.latitude).abs() < samePlaceEpsilonDegrees &&
    (a.longitude - b.longitude).abs() < samePlaceEpsilonDegrees;

/// Whether some other segment in [segments] covers the same two waypoints
/// as [segment] but in the opposite direction — e.g. [segment] is the
/// Chiang Mai -> Pai leg and another segment goes Pai -> Chiang Mai.
/// Segments with no such reverse leg render as a straight line on the map;
/// ones that do are curved (see [curvedPath]) so the two overlapping
/// directions stay visually distinct.
bool hasReverseLeg(List<TripSegment> segments, TripSegment segment) =>
    segments.any(
      (other) =>
          other.id != segment.id &&
          sameWaypoint(other.origin, segment.destination) &&
          sameWaypoint(other.destination, segment.origin),
    );

/// Points tracing a path from (startLat, startLng) to (endLat, endLng) — a
/// straight 2-point line if [curved] is false, otherwise a quadratic Bezier
/// arc bowed to one side of the straight line.
///
/// The bow direction is always "left of this segment's own travel
/// direction" (start -> end), computed fresh per segment rather than
/// tracked as outbound-vs-return state. That has a convenient side effect:
/// a return leg's start/end are the outbound leg's end/start, so its
/// direction vector is the outbound's negated — and "left of a negated
/// vector" is the mirror image of "left of the original vector". The two
/// directions of the same to-and-fro pair bow to opposite sides of the
/// straight line automatically, with no need to detect which leg is the
/// "outbound" one.
List<(double lat, double lng)> curvedPath({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
  required bool curved,
}) {
  if (!curved) {
    return [(startLat, startLng), (endLat, endLng)];
  }

  // Treat (lng, lat) as a flat (x, y) plane — accurate enough at city/
  // country scale for a purely cosmetic offset — so rotating the travel
  // direction left matches compass-left on screen.
  final dx = endLng - startLng;
  final dy = endLat - startLat;
  final dist = sqrt(dx * dx + dy * dy);
  if (dist == 0) {
    return [(startLat, startLng), (endLat, endLng)];
  }

  const curveFactor = 0.15;
  final perpLng = -dy / dist;
  final perpLat = dx / dist;
  final controlLng = (startLng + endLng) / 2 + perpLng * dist * curveFactor;
  final controlLat = (startLat + endLat) / 2 + perpLat * dist * curveFactor;

  const steps = 24;
  return [
    for (var i = 0; i <= steps; i++)
      _quadraticBezierPoint(
        t: i / steps,
        startLat: startLat,
        startLng: startLng,
        controlLat: controlLat,
        controlLng: controlLng,
        endLat: endLat,
        endLng: endLng,
      ),
  ];
}

(double lat, double lng) _quadraticBezierPoint({
  required double t,
  required double startLat,
  required double startLng,
  required double controlLat,
  required double controlLng,
  required double endLat,
  required double endLng,
}) {
  final oneMinusT = 1 - t;
  final a = oneMinusT * oneMinusT;
  final b = 2 * oneMinusT * t;
  final c = t * t;
  return (
    a * startLat + b * controlLat + c * endLat,
    a * startLng + b * controlLng + c * endLng,
  );
}
