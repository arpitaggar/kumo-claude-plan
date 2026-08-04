import 'dart:math';

/// A point along a sampled route path, with the compass bearing (0 = north,
/// 90 = east, ...) of local travel direction at that point.
///
/// Bearing is computed on the same flat (lng, lat) plane as
/// `route_curve.dart`'s bow-offset math — accurate enough at city/country
/// scale for orienting an icon, not for real navigation.
class RoutePoint {
  const RoutePoint({
    required this.lat,
    required this.lng,
    required this.bearingDegrees,
  });

  final double lat;
  final double lng;
  final double bearingDegrees;
}

double _bearingDegrees({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  final dLat = toLat - fromLat;
  final dLng = toLng - fromLng;
  if (dLat == 0 && dLng == 0) return 0;
  final radians = atan2(dLng, dLat);
  final degrees = radians * 180 / pi;
  return (degrees + 360) % 360;
}

double _segmentLength(double lat1, double lng1, double lat2, double lng2) {
  final dLat = lat2 - lat1;
  final dLng = lng2 - lng1;
  return sqrt(dLat * dLat + dLng * dLng);
}

/// Total arc length of [path] on the flat (lng, lat) plane.
double pathLength(List<(double, double)> path) {
  var total = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    total += _segmentLength(
      path[i].$1,
      path[i].$2,
      path[i + 1].$1,
      path[i + 1].$2,
    );
  }
  return total;
}

/// The point at arc-length fraction [t] (0 = start, 1 = end) along [path],
/// with the local bearing at that point. [path] must have at least 2 points.
RoutePoint pointAtFraction(List<(double, double)> path, double t) {
  assert(path.length >= 2);
  final clamped = t.clamp(0.0, 1.0);
  final total = pathLength(path);
  if (total == 0) {
    final bearing = _bearingDegrees(
      fromLat: path.first.$1,
      fromLng: path.first.$2,
      toLat: path.last.$1,
      toLng: path.last.$2,
    );
    return RoutePoint(
      lat: path.first.$1,
      lng: path.first.$2,
      bearingDegrees: bearing,
    );
  }

  final target = total * clamped;
  var walked = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    final (lat1, lng1) = path[i];
    final (lat2, lng2) = path[i + 1];
    final segLength = _segmentLength(lat1, lng1, lat2, lng2);
    final bearing = _bearingDegrees(
      fromLat: lat1,
      fromLng: lng1,
      toLat: lat2,
      toLng: lng2,
    );
    if (segLength == 0) continue;
    if (walked + segLength >= target || i == path.length - 2) {
      final segT = ((target - walked) / segLength).clamp(0.0, 1.0);
      return RoutePoint(
        lat: lat1 + (lat2 - lat1) * segT,
        lng: lng1 + (lng2 - lng1) * segT,
        bearingDegrees: bearing,
      );
    }
    walked += segLength;
  }

  final bearing = _bearingDegrees(
    fromLat: path[path.length - 2].$1,
    fromLng: path[path.length - 2].$2,
    toLat: path.last.$1,
    toLng: path.last.$2,
  );
  return RoutePoint(
    lat: path.last.$1,
    lng: path.last.$2,
    bearingDegrees: bearing,
  );
}

/// [count] points evenly spaced by arc length along [path], centred within
/// each of [count] equal-length slices (so ticks don't land exactly on the
/// endpoints, where they'd overlap the origin/destination markers).
List<RoutePoint> sampleEvenly(List<(double, double)> path, int count) {
  if (count <= 0 || path.length < 2) return const [];
  return [
    for (var i = 0; i < count; i++) pointAtFraction(path, (i + 0.5) / count),
  ];
}

/// [path] shifted perpendicular to its own local direction by [amount]
/// (in the same lat/lng-degree units as [path] itself), scaled by the
/// caller to the segment's own length — a fixed real-world offset (e.g.
/// true tyre-track/rail gauge) would be geographically invisible at the
/// zoom levels this app's trip map is used at.
///
/// Used only by the Google Maps engine, which — unlike the OSM engine's
/// custom screen-space painter (see route_line_painter.dart) — has no way
/// to draw a constant-pixel-width parallel line, so its double-tread/
/// train-track legs fall back to this geometry-based approximation.
List<(double, double)> offsetPath(List<(double, double)> path, double amount) {
  if (path.length < 2 || amount == 0) return path;
  return [for (var i = 0; i < path.length; i++) _offsetPoint(path, i, amount)];
}

(double, double) _offsetPoint(
  List<(double, double)> path,
  int i,
  double amount,
) {
  final prev = path[max(0, i - 1)];
  final next = path[min(path.length - 1, i + 1)];
  final dLat = next.$1 - prev.$1;
  final dLng = next.$2 - prev.$2;
  final dist = sqrt(dLat * dLat + dLng * dLng);
  if (dist == 0) return path[i];
  final perpLng = -dLat / dist;
  final perpLat = dLng / dist;
  return (path[i].$1 + perpLat * amount, path[i].$2 + perpLng * amount);
}
