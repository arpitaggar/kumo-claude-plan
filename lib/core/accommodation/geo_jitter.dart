import 'dart:math';

/// Moves ([lat],[lng]) [km] along [bearingRadians] — a flat-earth
/// approximation, more than accurate enough for scattering mock listings
/// within a couple of kilometers of a search center. Shared by every
/// `mock_*_source.dart` file (plumbing, not source-specific business logic
/// — unlike the sources themselves, which stay deliberately independent of
/// each other per this feature's CLAUDE.md).
(double, double) offsetLatLng(
  double lat,
  double lng,
  double km,
  double bearingRadians,
) {
  const kmPerDegreeLat = 111.0;
  final kmPerDegreeLng = 111.0 * cos(lat * pi / 180);
  final dLat = km * cos(bearingRadians) / kmPerDegreeLat;
  final dLng = kmPerDegreeLng == 0
      ? 0.0
      : km * sin(bearingRadians) / kmPerDegreeLng;
  return (lat + dLat, lng + dLng);
}
