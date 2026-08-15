import 'dart:math';

import 'accommodation_listing.dart';
import 'accommodation_source.dart';
import 'geo_jitter.dart';

/// Fixture data standing in for a real Expedia integration (Expedia Group's
/// Rapid API / EPS affiliate program) — see this feature's CLAUDE.md for
/// how to wire up a real source once that partnership exists.
class MockExpediaSource implements AccommodationSource {
  @override
  String get sourceKey => 'expedia';

  static const _names = [
    'Grand Plaza Hotel',
    'City Center Suites',
    'The Riverside Hotel',
    'Metro Business Hotel',
    'Boutique Hotel Aurora',
  ];

  @override
  Future<List<AccommodationListing>> search(
    AccommodationSearchQuery query,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final rand = Random();
    return List.generate(_names.length, (i) {
      final (lat, lng) = offsetLatLng(
        query.latitude,
        query.longitude,
        rand.nextDouble() * query.radiusKm,
        rand.nextDouble() * 2 * pi,
      );
      return AccommodationListing(
        id: 'expedia-$i',
        sourceKey: sourceKey,
        name: _names[i],
        propertyType: PropertyType.hotel,
        pricePerNight: 70 + rand.nextInt(200).toDouble(),
        currencyCode: 'USD',
        latitude: lat,
        longitude: lng,
        bookingUrl: Uri.parse('https://www.expedia.com/Hotel-Search'),
        rating: 3.5 + rand.nextDouble() * 1.5,
      );
    });
  }
}
