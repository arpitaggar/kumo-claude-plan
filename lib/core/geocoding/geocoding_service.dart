import 'package:equatable/equatable.dart';

/// A single place matched from a geocoding search — used for both map
/// providers' location search (typing "Chiang Mai" -> lat/lng), so users
/// never need a Google key just to enter a city name.
class GeocodingResult extends Equatable {
  const GeocodingResult({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  @override
  List<Object> get props => [name, latitude, longitude];
}

abstract class GeocodingService {
  Future<List<GeocodingResult>> search(String query);
}
