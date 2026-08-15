import 'dart:math';

/// Great-circle distance between two points, in kilometers (haversine
/// formula). Used by `CombinedAccommodationSource`
/// (combined_accommodation_source.dart) to re-apply the search radius
/// authoritatively after aggregation — a source is trusted to try to honor
/// `AccommodationSearchQuery.radiusKm` but not relied upon to, the same way
/// its price bounds aren't either.
double haversineDistanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) *
          cos(_degToRad(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * pi / 180;
