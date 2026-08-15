import 'dart:math';

import 'accommodation_listing.dart';
import 'accommodation_source.dart';
import 'geo_jitter.dart';

/// Fixture data standing in for a real Airbnb integration — see this
/// feature's CLAUDE.md for why: Airbnb has no public listings API for
/// third parties at all, realistically, unlike the OTAs below which at
/// least have an approval-gated affiliate/search tier to eventually
/// integrate against.
///
/// Returns individual host-style listings only (apartments) — deliberately
/// no [PropertyType.hotel]/[PropertyType.hostel] results, matching
/// Airbnb's real inventory shape.
class MockAirbnbSource implements AccommodationSource {
  @override
  String get sourceKey => 'airbnb';

  static const _names = [
    'Cozy studio near the old town',
    'Sunny 1BR with balcony',
    'Charming loft, walk to everything',
    'Modern apartment with city view',
    'Quiet garden flat',
  ];

  @override
  Future<List<AccommodationListing>> search(
    AccommodationSearchQuery query,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final rand = Random();
    return List.generate(_names.length, (i) {
      final (lat, lng) = offsetLatLng(
        query.latitude,
        query.longitude,
        rand.nextDouble() * query.radiusKm,
        rand.nextDouble() * 2 * pi,
      );
      return AccommodationListing(
        id: 'airbnb-$i',
        sourceKey: sourceKey,
        name: _names[i],
        propertyType: PropertyType.apartment,
        pricePerNight: 45 + rand.nextInt(120).toDouble(),
        currencyCode: 'USD',
        latitude: lat,
        longitude: lng,
        bookingUrl: Uri.parse('https://www.airbnb.com/s/homes'),
        rating: 4.0 + rand.nextDouble(),
      );
    });
  }
}
