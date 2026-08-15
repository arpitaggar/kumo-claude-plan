import 'accommodation_listing.dart';

/// A single accommodation data source. Implementations are self-contained
/// and interchangeable — see `CombinedAccommodationSource`
/// (combined_accommodation_source.dart) for how an unordered list of these
/// is queried in parallel and merged into one result, unlike
/// `lib/core/weather/`'s `FallbackWeatherService`-style "first hit wins":
/// every enabled source's listings are shown together, not just the best
/// one.
// ignore: one_member_abstracts
abstract class AccommodationSource {
  /// Matches this source's `AccommodationSourceMeta.key`
  /// (accommodation_source_meta.dart) — every [AccommodationListing] this
  /// source returns must carry the same value as its own `sourceKey`.
  String get sourceKey;

  /// Returns listings matching [query]. Throws on a genuine failure
  /// (network/parse error) — an empty list is the correct, non-error
  /// response for "no matches," mirroring `WeatherService.forecastFor`'s
  /// null-means-no-coverage convention in `lib/core/weather/`.
  /// `CombinedAccommodationSource` is what catches a thrown failure and
  /// degrades gracefully; individual sources should not swallow their own
  /// errors.
  Future<List<AccommodationListing>> search(AccommodationSearchQuery query);
}
