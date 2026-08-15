import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'transport_mode.dart';
import 'travel_itinerary.dart';
import 'trip_segment.dart';
import 'waypoint.dart';

/// A portable, shareable snapshot of a trip — the payload of a `.json` file
/// a user can export and hand to someone else (AirDrop/email/message) to
/// recreate the trip in their own Kumo account.
///
/// Deliberately scoped to the same boundary `ForkPostUseCase`/`ItineraryPost`
/// already draws for "clone this trip into a different account": title,
/// dates, theme, currency, items, and route segments only. Never members,
/// expenses, or notes — those either name other real people or carry
/// financial data that isn't the exporting user's alone to hand out.
///
/// This is a standalone format, not a dump of the backend row shape — it
/// intentionally doesn't reuse `ItineraryModel`/`TripSegmentModel`'s JSON so
/// that a future change to the Supabase schema can't silently break old
/// export files sitting in someone's inbox.
class TripFile extends Equatable {
  const TripFile({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.currencyCode,
    required this.themeKey,
    required this.items,
    required this.segments,
    this.description,
  });

  /// Builds a [TripFile] snapshot of [itinerary] and its [segments].
  factory TripFile.fromItinerary({
    required TravelItinerary itinerary,
    required List<TripFileSegment> segments,
  }) => TripFile(
    title: itinerary.title,
    description: itinerary.description,
    startDate: itinerary.startDate,
    endDate: itinerary.endDate,
    currencyCode: itinerary.currencyCode,
    themeKey: itinerary.themeKey,
    items: itinerary.items,
    segments: segments,
  );

  /// Parses a decoded JSON map back into a [TripFile].
  ///
  /// @throws FormatException if [json] isn't a recognizable Kumo trip file,
  /// or was exported by a newer version of the app than this one supports.
  factory TripFile.fromJson(Map<String, dynamic> json) {
    final version = json['kumo_trip_file_version'];
    if (version is! int) {
      throw const FormatException("This doesn't look like a Kumo trip file.");
    }
    if (version > currentVersion) {
      throw const FormatException(
        'This trip file was exported by a newer version of Kumo. Please '
        'update the app and try again.',
      );
    }

    final title = json['title'];
    final startDate = json['start_date'];
    final endDate = json['end_date'];
    final currencyCode = json['currency_code'];
    if (title is! String ||
        title.isEmpty ||
        startDate is! String ||
        endDate is! String ||
        currencyCode is! String) {
      throw const FormatException('This trip file is missing required data.');
    }

    return TripFile(
      title: title,
      description: json['description'] as String?,
      startDate: DateTime.parse(startDate),
      endDate: DateTime.parse(endDate),
      currencyCode: currencyCode,
      themeKey: json['theme_key'] as String? ?? 'classic',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => _itemFromJson(i as Map<String, dynamic>))
              .toList() ??
          const [],
      segments:
          (json['segments'] as List<dynamic>?)
              ?.map((s) => TripFileSegment.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Bumped whenever the shape of this format changes in a way old readers
  /// couldn't tolerate. `TripFile.fromJson` rejects anything newer than
  /// this.
  static const currentVersion = 1;

  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String currencyCode;
  final String themeKey;
  final List<ItineraryItem> items;
  final List<TripFileSegment> segments;

  Map<String, dynamic> toJson() => {
    'kumo_trip_file_version': currentVersion,
    'title': title,
    if (description != null && description!.isNotEmpty)
      'description': description,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'currency_code': currencyCode,
    'theme_key': themeKey,
    'items': items.map(_itemToJson).toList(),
    'segments': segments.map((s) => s.toJson()).toList(),
  };

  @override
  List<Object?> get props => [
    title,
    description,
    startDate,
    endDate,
    currencyCode,
    themeKey,
    items,
    segments,
  ];
}

Map<String, dynamic> _itemToJson(ItineraryItem item) => {
  'item_type': item.itemType,
  'title': item.title,
  'start_time': item.startTime.toIso8601String(),
  if (item.endTime != null) 'end_time': item.endTime!.toIso8601String(),
  if (item.location != null) 'location': item.location,
  if (item.latitude != null) 'latitude': item.latitude,
  if (item.longitude != null) 'longitude': item.longitude,
};

ItineraryItem _itemFromJson(Map<String, dynamic> json) => ItineraryItem(
  id: const Uuid().v4(),
  itemType: json['item_type'] as String? ?? 'activity',
  title: json['title'] as String? ?? 'Untitled',
  startTime: DateTime.parse(json['start_time'] as String),
  endTime: json['end_time'] != null
      ? DateTime.parse(json['end_time'] as String)
      : null,
  location: json['location'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
);

/// One leg of the route, as carried in a [TripFile] — the same shape as
/// [TripSegment] minus [TripSegment.id]/[TripSegment.itineraryId] (assigned
/// fresh on import) and `routeGeometry` (cheap to re-fetch from the routing
/// service on import, same as adding a segment by hand; not worth the file
/// size for a long route).
class TripFileSegment extends Equatable {
  const TripFileSegment({
    required this.orderIndex,
    required this.mode,
    required this.origin,
    required this.destination,
    this.departureTime,
    this.arrivalTime,
    this.notes,
  });

  factory TripFileSegment.fromEntity(TripSegment segment) => TripFileSegment(
    orderIndex: segment.orderIndex,
    mode: segment.mode,
    origin: segment.origin,
    destination: segment.destination,
    departureTime: segment.departureTime,
    arrivalTime: segment.arrivalTime,
    notes: segment.notes,
  );

  factory TripFileSegment.fromJson(Map<String, dynamic> json) {
    final modeStr = json['transport_mode'] as String? ?? 'other';
    return TripFileSegment(
      orderIndex: json['order_index'] as int? ?? 0,
      mode: TransportMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => TransportMode.other,
      ),
      origin: Waypoint(
        name: json['origin_name'] as String? ?? '',
        latitude: (json['origin_lat'] as num).toDouble(),
        longitude: (json['origin_lng'] as num).toDouble(),
      ),
      destination: Waypoint(
        name: json['destination_name'] as String? ?? '',
        latitude: (json['destination_lat'] as num).toDouble(),
        longitude: (json['destination_lng'] as num).toDouble(),
      ),
      departureTime: json['departure_time'] != null
          ? DateTime.parse(json['departure_time'] as String)
          : null,
      arrivalTime: json['arrival_time'] != null
          ? DateTime.parse(json['arrival_time'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  final int orderIndex;
  final TransportMode mode;
  final Waypoint origin;
  final Waypoint destination;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final String? notes;

  Map<String, dynamic> toJson() => {
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
  };

  @override
  List<Object?> get props => [
    orderIndex,
    mode,
    origin,
    destination,
    departureTime,
    arrivalTime,
    notes,
  ];
}
