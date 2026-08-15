import 'package:equatable/equatable.dart';

/// What kind of place a listing is — drives which icon a card shows and,
/// eventually, whether it's a candidate for a future cross-source
/// price-compare merge (only hotels/hostels can plausibly be resold by
/// multiple OTAs; an Airbnb apartment listing never is — see
/// `lib/core/accommodation/CLAUDE.md`).
enum PropertyType {
  hotel('Hotel'),
  hostel('Hostel'),
  apartment('Apartment'),
  other('Other');

  const PropertyType(this.label);

  final String label;
}

/// What a caller asks an `AccommodationSource` (accommodation_source.dart)
/// for. All sources receive the exact same query shape regardless of how
/// differently their underlying API is structured — normalizing the
/// request, not just the response, is what lets
/// `CombinedAccommodationSource` (combined_accommodation_source.dart) query
/// every enabled source with one call.
class AccommodationSearchQuery extends Equatable {
  const AccommodationSearchQuery({
    required this.latitude,
    required this.longitude,
    required this.checkIn,
    required this.checkOut,
    this.radiusKm = 2,
    this.guests = 2,
    this.minPricePerNight,
    this.maxPricePerNight,
  });

  /// Search center — see `lib/core/accommodation/CLAUDE.md` for why v1 only
  /// ever derives this from the trip's own destination, with no manual
  /// "pick a different center point" control yet.
  final double latitude;
  final double longitude;
  final double radiusKm;

  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;

  /// Sources are free to ignore these and return everything in range — the
  /// authoritative price filter is always re-applied client-side after
  /// aggregation, since not every mock/real source can be trusted to honor
  /// them server-side.
  final double? minPricePerNight;
  final double? maxPricePerNight;

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    radiusKm,
    checkIn,
    checkOut,
    guests,
    minPricePerNight,
    maxPricePerNight,
  ];
}

/// One bookable place, from one source. Deliberately **not** deduplicated
/// or merged across sources — the same physical hotel available on both
/// Expedia and Booking.com is two separate [AccommodationListing]s, each
/// carrying its own [sourceKey]/[bookingUrl]/[pricePerNight]. See
/// `lib/core/accommodation/CLAUDE.md` for why cross-source entity
/// resolution is a deliberately deferred v2 concern, not a v1 gap.
class AccommodationListing extends Equatable {
  const AccommodationListing({
    required this.id,
    required this.sourceKey,
    required this.name,
    required this.propertyType,
    required this.pricePerNight,
    required this.currencyCode,
    required this.latitude,
    required this.longitude,
    required this.bookingUrl,
    this.thumbnailUrl,
    this.rating,
  });

  /// Unique only within [sourceKey] — two different sources may reuse the
  /// same raw id space, so callers that need a globally-unique key should
  /// combine `sourceKey:id`.
  final String id;

  /// Matches an `AccommodationSourceMeta.key` (accommodation_source_meta.dart)
  /// — the join key between a listing and its source's display metadata
  /// (name, badge color) for rendering.
  final String sourceKey;

  final String name;
  final PropertyType propertyType;

  final double pricePerNight;
  final String currencyCode;

  final double latitude;
  final double longitude;

  final String? thumbnailUrl;

  /// 0-5, or null if the source doesn't report one.
  final double? rating;

  /// Where "View on <Source>" sends the user to actually book — Kumo never
  /// processes the booking itself (the Skyscanner-style metasearch model
  /// discussed when this feature was designed: show a comparison, redirect
  /// out to transact).
  final Uri bookingUrl;

  @override
  List<Object?> get props => [
    id,
    sourceKey,
    name,
    propertyType,
    pricePerNight,
    currencyCode,
    latitude,
    longitude,
    thumbnailUrl,
    rating,
    bookingUrl,
  ];
}
