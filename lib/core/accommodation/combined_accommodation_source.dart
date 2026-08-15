import '../utils/logger.dart';
import 'accommodation_listing.dart';
import 'accommodation_source.dart';
import 'geo_distance.dart';

/// The result of querying multiple [AccommodationSource]s at once —
/// [listings] from whichever sources succeeded, plus [failedSourceKeys] so
/// the UI can show "Expedia unavailable right now" without losing the
/// results that did come back. A single source failing must never make the
/// whole search look empty/broken.
class AccommodationSearchResult {
  const AccommodationSearchResult({
    required this.listings,
    required this.failedSourceKeys,
  });

  final List<AccommodationListing> listings;
  final List<String> failedSourceKeys;
}

/// Queries every source in [sources] **in parallel** and merges their
/// results into one flat list — unlike `lib/core/weather/`'s
/// `FallbackWeatherService`, which tries sources in order and stops at the
/// first hit, this is a "show me everything" aggregator: the whole point
/// is comparing options across sources side by side, not picking one
/// winner. Two different sources returning what's really the same physical
/// hotel are intentionally NOT merged — see `AccommodationListing`'s doc
/// comment.
///
/// Each source's failure is caught independently (mirrors
/// `FallbackWeatherService`'s per-source try/catch) so one broken source
/// can't take the others down with it.
class CombinedAccommodationSource {
  CombinedAccommodationSource(this.sources);

  final List<AccommodationSource> sources;

  Future<AccommodationSearchResult> search(
    AccommodationSearchQuery query,
  ) async {
    final failedSourceKeys = <String>[];
    final results = await Future.wait(
      sources.map((source) async {
        try {
          return await source.search(query);
        } catch (e) {
          AppLogger.warning(
            '${source.runtimeType} (${source.sourceKey}) failed to '
            'search, showing other sources\' results: $e',
          );
          failedSourceKeys.add(source.sourceKey);
          return const <AccommodationListing>[];
        }
      }),
    );

    final listings = results
        .expand((l) => l)
        // Re-applies radius/price authoritatively — a source is trusted to
        // try to honor these, not relied upon to (see
        // AccommodationSearchQuery's doc comment).
        .where(
          (l) =>
              haversineDistanceKm(
                query.latitude,
                query.longitude,
                l.latitude,
                l.longitude,
              ) <=
              query.radiusKm,
        )
        .where(
          (l) =>
              query.minPricePerNight == null ||
              l.pricePerNight >= query.minPricePerNight!,
        )
        .where(
          (l) =>
              query.maxPricePerNight == null ||
              l.pricePerNight <= query.maxPricePerNight!,
        )
        .toList();

    return AccommodationSearchResult(
      listings: listings,
      failedSourceKeys: failedSourceKeys,
    );
  }
}
