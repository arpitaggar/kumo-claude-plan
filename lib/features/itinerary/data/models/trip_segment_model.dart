import '../../domain/entities/transport_mode.dart';
import '../../domain/entities/trip_segment.dart';
import '../../domain/entities/waypoint.dart';

class TripSegmentModel extends TripSegment {
  const TripSegmentModel({
    required super.id,
    required super.itineraryId,
    required super.orderIndex,
    required super.mode,
    required super.origin,
    required super.destination,
    super.departureTime,
    super.arrivalTime,
    super.notes,
    super.routeGeometry,
    super.isVisible,
  });

  factory TripSegmentModel.fromJson(Map<String, dynamic> json) {
    final modeStr = json['transport_mode'] as String? ?? 'other';
    final mode = TransportMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => TransportMode.other,
    );

    return TripSegmentModel(
      id: json['id'] as String,
      itineraryId: json['itinerary_id'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      mode: mode,
      origin: Waypoint(
        name: json['origin_name'] as String,
        latitude: (json['origin_lat'] as num).toDouble(),
        longitude: (json['origin_lng'] as num).toDouble(),
      ),
      destination: Waypoint(
        name: json['destination_name'] as String,
        latitude: (json['destination_lat'] as num).toDouble(),
        longitude: (json['destination_lng'] as num).toDouble(),
      ),
      departureTime: json['departure_time'] != null
          ? DateTime.parse(json['departure_time'] as String).toUtc()
          : null,
      arrivalTime: json['arrival_time'] != null
          ? DateTime.parse(json['arrival_time'] as String).toUtc()
          : null,
      notes: json['notes'] as String?,
      routeGeometry: _routeGeometryFromJson(json['route_geometry']),
      isVisible: json['is_visible'] as bool? ?? true,
    );
  }

  factory TripSegmentModel.fromEntity(TripSegment segment) => TripSegmentModel(
    id: segment.id,
    itineraryId: segment.itineraryId,
    orderIndex: segment.orderIndex,
    mode: segment.mode,
    origin: segment.origin,
    destination: segment.destination,
    departureTime: segment.departureTime,
    arrivalTime: segment.arrivalTime,
    notes: segment.notes,
    routeGeometry: segment.routeGeometry,
    isVisible: segment.isVisible,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'itinerary_id': itineraryId,
    'order_index': orderIndex,
    'transport_mode': mode.name,
    'origin_name': origin.name,
    'origin_lat': origin.latitude,
    'origin_lng': origin.longitude,
    'destination_name': destination.name,
    'destination_lat': destination.latitude,
    'destination_lng': destination.longitude,
    if (departureTime != null)
      'departure_time': departureTime!.toIso8601String(),
    if (arrivalTime != null) 'arrival_time': arrivalTime!.toIso8601String(),
    if (notes != null) 'notes': notes,
    if (routeGeometry != null)
      'route_geometry': [
        for (final (lat, lng) in routeGeometry!) [lat, lng],
      ],
    'is_visible': isVisible,
  };
}

/// `route_geometry` is a `jsonb` array of `[lat, lng]` pairs, or null.
List<(double, double)>? _routeGeometryFromJson(Object? raw) {
  if (raw is! List) {
    return null;
  }
  return [
    for (final point in raw)
      (
        ((point as List<dynamic>)[0] as num).toDouble(),
        (point[1] as num).toDouble(),
      ),
  ];
}
