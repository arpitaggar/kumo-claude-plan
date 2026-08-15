import 'dart:math';

import 'accommodation_listing.dart';
import 'accommodation_source.dart';
import 'geo_jitter.dart';

/// Fixture data standing in for a real Booking.com integration (Booking.com
/// Affiliate Partner Program) — see this feature's CLAUDE.md for how to
/// wire up a real source once that partnership exists.
///
/// Deliberately reuses two hotel names from `MockExpediaSource`'s fixture
/// list ("Grand Plaza Hotel", "The Riverside Hotel") at a similar price —
/// this is what a real hotel resold by multiple OTAs looks like, and v1's
/// job is to show it as two separate rows (one per source), not merge
/// them. See `AccommodationListing`'s doc comment for why cross-source
/// merging is a deferred v2 concern.
class MockBookingSource implements AccommodationSource {
  @override
  String get sourceKey => 'booking';

  static const _hotelNames = [
    'Grand Plaza Hotel',
    'The Riverside Hotel',
    'Harbor View Inn',
  ];
  static const _hostelNames = ['Backpacker\'s Nest', 'Sunset Hostel'];

  @override
  Future<List<AccommodationListing>> search(
    AccommodationSearchQuery query,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final rand = Random();
    final hotels = List.generate(_hotelNames.length, (i) {
      final (lat, lng) = offsetLatLng(
        query.latitude,
        query.longitude,
        rand.nextDouble() * query.radiusKm,
        rand.nextDouble() * 2 * pi,
      );
      return AccommodationListing(
        id: 'booking-hotel-$i',
        sourceKey: sourceKey,
        name: _hotelNames[i],
        propertyType: PropertyType.hotel,
        pricePerNight: 65 + rand.nextInt(210).toDouble(),
        currencyCode: 'USD',
        latitude: lat,
        longitude: lng,
        bookingUrl: Uri.parse('https://www.booking.com/searchresults.html'),
        rating: 3.5 + rand.nextDouble() * 1.5,
      );
    });
    final hostels = List.generate(_hostelNames.length, (i) {
      final (lat, lng) = offsetLatLng(
        query.latitude,
        query.longitude,
        rand.nextDouble() * query.radiusKm,
        rand.nextDouble() * 2 * pi,
      );
      return AccommodationListing(
        id: 'booking-hostel-$i',
        sourceKey: sourceKey,
        name: _hostelNames[i],
        propertyType: PropertyType.hostel,
        pricePerNight: 15 + rand.nextInt(40).toDouble(),
        currencyCode: 'USD',
        latitude: lat,
        longitude: lng,
        bookingUrl: Uri.parse('https://www.booking.com/searchresults.html'),
        rating: 3.0 + rand.nextDouble() * 1.5,
      );
    });
    return [...hotels, ...hostels];
  }
}
