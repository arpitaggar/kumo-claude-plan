import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/accommodation/accommodation_listing.dart';
import 'package:kumo_claude/core/accommodation/mock_airbnb_source.dart';
import 'package:kumo_claude/core/accommodation/mock_booking_source.dart';
import 'package:kumo_claude/core/accommodation/mock_expedia_source.dart';
import 'package:kumo_claude/core/accommodation/mock_hostelworld_source.dart';

final _query = AccommodationSearchQuery(
  latitude: 45.4384,
  longitude: 10.9916,
  checkIn: DateTime(2026, 6),
  checkOut: DateTime(2026, 6, 5),
);

void _expectStructurallySound(
  List<AccommodationListing> listings, {
  required String sourceKey,
}) {
  expect(listings, isNotEmpty);
  for (final listing in listings) {
    expect(listing.sourceKey, sourceKey);
    expect(listing.id, isNotEmpty);
    expect(listing.name, isNotEmpty);
    expect(listing.pricePerNight, greaterThan(0));
    expect(listing.currencyCode, isNotEmpty);
    // Every mock jitters within the query's own radius (geo_jitter.dart).
    expect(listing.latitude, closeTo(_query.latitude, 0.1));
    expect(listing.longitude, closeTo(_query.longitude, 0.1));
    expect(listing.bookingUrl.hasScheme, isTrue);
  }
  // ids are unique within one source's own result set.
  expect(listings.map((l) => l.id).toSet(), hasLength(listings.length));
}

void main() {
  group('MockAirbnbSource', () {
    test('returns apartment-only listings', () async {
      final listings = await MockAirbnbSource().search(_query);
      _expectStructurallySound(listings, sourceKey: 'airbnb');
      expect(
        listings.every((l) => l.propertyType == PropertyType.apartment),
        isTrue,
      );
    });
  });

  group('MockExpediaSource', () {
    test('returns hotel-only listings', () async {
      final listings = await MockExpediaSource().search(_query);
      _expectStructurallySound(listings, sourceKey: 'expedia');
      expect(
        listings.every((l) => l.propertyType == PropertyType.hotel),
        isTrue,
      );
    });
  });

  group('MockBookingSource', () {
    test('returns a mix of hotels and hostels', () async {
      final listings = await MockBookingSource().search(_query);
      _expectStructurallySound(listings, sourceKey: 'booking');
      expect(listings.any((l) => l.propertyType == PropertyType.hotel), isTrue);
      expect(
        listings.any((l) => l.propertyType == PropertyType.hostel),
        isTrue,
      );
    });

    test('includes two hotel names that also appear in MockExpediaSource\'s '
        'fixtures — the deliberate "same hotel, two sources" case', () async {
      final bookingListings = await MockBookingSource().search(_query);
      final expediaListings = await MockExpediaSource().search(_query);

      final bookingNames = bookingListings.map((l) => l.name).toSet();
      final expediaNames = expediaListings.map((l) => l.name).toSet();
      final shared = bookingNames.intersection(expediaNames);

      expect(shared, isNotEmpty);
    });
  });

  group('MockHostelworldSource', () {
    test('returns hostel-only listings', () async {
      final listings = await MockHostelworldSource().search(_query);
      _expectStructurallySound(listings, sourceKey: 'hostelworld');
      expect(
        listings.every((l) => l.propertyType == PropertyType.hostel),
        isTrue,
      );
    });
  });
}
