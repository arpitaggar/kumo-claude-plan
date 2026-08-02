import 'package:equatable/equatable.dart';

/// A named point on the map (city, airport, station, ...). Denormalised onto
/// each [TripSegment] rather than shared — see trip_segment.dart for why.
class Waypoint extends Equatable {
  const Waypoint({
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
