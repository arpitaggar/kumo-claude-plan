import 'package:flutter/painting.dart' show Color;

/// Display metadata for one known accommodation source — the catalog
/// settings UI (profile + per-trip pickers) renders from, independent of
/// whether that source actually has a real `AccommodationSource`
/// (accommodation_source.dart) implementation wired up yet in
/// `accommodation_providers.dart`. A source can be "known" here before
/// it's "fetchable" — see `lib/core/accommodation/CLAUDE.md`.
///
/// [badgeColor] is a deliberate placeholder, not a trademarked logo — see
/// this feature's CLAUDE.md for why real platform logos aren't used until
/// an actual partnership with that platform exists.
class AccommodationSourceMeta {
  const AccommodationSourceMeta({
    required this.key,
    required this.displayName,
    required this.badgeColor,
  });

  /// Stable identifier, matches `AccommodationSource.sourceKey` and every
  /// `AccommodationListing.sourceKey` it produces, plus what's persisted in
  /// `profiles.enabled_accommodation_sources`/`itineraries
  /// .accommodation_sources`. Never rename an existing key — it's stored
  /// data, not just a UI label.
  final String key;

  final String displayName;
  final Color badgeColor;
}

/// Every source Kumo knows about. The single place a new source is
/// registered for display purposes — see `accommodation_providers.dart`
/// for where a source additionally needs a real fetch implementation
/// wired in to actually return results.
const kAccommodationSources = [
  AccommodationSourceMeta(
    key: 'airbnb',
    displayName: 'Airbnb',
    badgeColor: Color(0xFFFF5A5F),
  ),
  AccommodationSourceMeta(
    key: 'expedia',
    displayName: 'Expedia',
    badgeColor: Color(0xFF1A73E8),
  ),
  AccommodationSourceMeta(
    key: 'booking',
    displayName: 'Booking.com',
    badgeColor: Color(0xFF003580),
  ),
  AccommodationSourceMeta(
    key: 'hostelworld',
    displayName: 'Hostelworld',
    badgeColor: Color(0xFFFF6E14),
  ),
];
