import 'dart:math';

import 'accommodation_listing.dart';
import 'accommodation_source.dart';
import 'geo_jitter.dart';

/// Fixture data standing in for a real Hostelworld integration — see this
/// feature's CLAUDE.md for how to wire up a real source once an affiliate
/// relationship exists. Budget-focused inventory only, matching
/// Hostelworld's real positioning.
class MockHostelworldSource implements AccommodationSource {
  @override
  String get sourceKey => 'hostelworld';

  static const _names = [
    'Wanderer\'s Hostel',
    'Old Town Backpackers',
    'The Social Hub Hostel',
    'Sunrise Budget Inn',
  ];

  @override
  Future<List<AccommodationListing>> search(
    AccommodationSearchQuery query,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final rand = Random();
    return List.generate(_names.length, (i) {
      final (lat, lng) = offsetLatLng(
        query.latitude,
        query.longitude,
        rand.nextDouble() * query.radiusKm,
        rand.nextDouble() * 2 * pi,
      );
      return AccommodationListing(
        id: 'hostelworld-$i',
        sourceKey: sourceKey,
        name: _names[i],
        propertyType: PropertyType.hostel,
        pricePerNight: 12 + rand.nextInt(35).toDouble(),
        currencyCode: 'USD',
        latitude: lat,
        longitude: lng,
        bookingUrl: Uri.parse('https://www.hostelworld.com/search'),
        rating: 3.2 + rand.nextDouble() * 1.6,
      );
    });
  }
}
