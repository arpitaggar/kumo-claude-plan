import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accommodation_listing.dart';
import 'accommodation_source.dart';
import 'accommodation_source_meta.dart';
import 'combined_accommodation_source.dart';
import 'mock_airbnb_source.dart';
import 'mock_booking_source.dart';
import 'mock_expedia_source.dart';
import 'mock_hostelworld_source.dart';

/// The full catalog of known sources, for settings UI (profile + per-trip
/// pickers) — see `accommodation_source_meta.dart`.
final accommodationSourceRegistryProvider =
    Provider<List<AccommodationSourceMeta>>((_) => kAccommodationSources);

/// Every source with a real (today: mock) fetch implementation wired up.
/// **The single place to swap a mock for a real, Edge-Function-backed
/// source** once a partnership exists — see `lib/core/accommodation/
/// CLAUDE.md`. Note this can be a strict subset of
/// [accommodationSourceRegistryProvider]'s keys (a source can be "known,"
/// i.e. shown in settings and toggleable, before it's actually fetchable)
/// — it never needs to be a superset, since a listing's `sourceKey` must
/// always resolve to a real [AccommodationSourceMeta] entry for the UI to
/// render its badge/name.
final accommodationSourcesProvider = Provider<List<AccommodationSource>>(
  (_) => [
    MockAirbnbSource(),
    MockExpediaSource(),
    MockBookingSource(),
    MockHostelworldSource(),
  ],
);

/// Family key for [accommodationSearchProvider] — the search query plus
/// which sources to actually query. [enabledSourceKeys] is applied
/// *before* fetching (not just filtering the results after), so a source
/// the user has toggled off is never called at all — matters once real
/// sources are metered/rate-limited API calls, not just mock data.
class AccommodationSearchRequest extends Equatable {
  const AccommodationSearchRequest({
    required this.query,
    required this.enabledSourceKeys,
  });

  final AccommodationSearchQuery query;
  final List<String> enabledSourceKeys;

  @override
  List<Object?> get props => [query, enabledSourceKeys];
}

final accommodationSearchProvider =
    FutureProvider.family<
      AccommodationSearchResult,
      AccommodationSearchRequest
    >((ref, request) {
      final enabled = ref
          .watch(accommodationSourcesProvider)
          .where((s) => request.enabledSourceKeys.contains(s.sourceKey))
          .toList();
      return CombinedAccommodationSource(enabled).search(request.query);
    });
