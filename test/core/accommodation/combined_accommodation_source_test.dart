import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/accommodation/accommodation_listing.dart';
import 'package:kumo_claude/core/accommodation/accommodation_source.dart';
import 'package:kumo_claude/core/accommodation/combined_accommodation_source.dart';

class _FakeSourceException implements Exception {
  const _FakeSourceException(this.message);
  final String message;
  @override
  String toString() => 'Exception: $message';
}

class _FakeSource implements AccommodationSource {
  _FakeSource(
    this.sourceKey, {
    List<AccommodationListing>? listings,
    this.error,
    this.delay = Duration.zero,
  }) : _listings = listings ?? const [];

  @override
  final String sourceKey;

  final List<AccommodationListing> _listings;
  final _FakeSourceException? error;
  final Duration delay;

  @override
  Future<List<AccommodationListing>> search(
    AccommodationSearchQuery query,
  ) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final e = error;
    if (e != null) {
      throw e;
    }
    return _listings;
  }
}

AccommodationListing _listing({
  required String id,
  required String sourceKey,
  double latitude = 45.4384,
  double longitude = 10.9916,
  double pricePerNight = 100,
}) => AccommodationListing(
  id: id,
  sourceKey: sourceKey,
  name: 'Listing $id',
  propertyType: PropertyType.hotel,
  pricePerNight: pricePerNight,
  currencyCode: 'USD',
  latitude: latitude,
  longitude: longitude,
  bookingUrl: Uri.parse('https://example.com/$id'),
);

AccommodationSearchQuery _query({
  double radiusKm = 2,
  double? minPricePerNight,
  double? maxPricePerNight,
}) => AccommodationSearchQuery(
  latitude: 45.4384,
  longitude: 10.9916,
  radiusKm: radiusKm,
  checkIn: DateTime(2026, 6),
  checkOut: DateTime(2026, 6, 5),
  minPricePerNight: minPricePerNight,
  maxPricePerNight: maxPricePerNight,
);

void main() {
  group('CombinedAccommodationSource', () {
    test('merges listings from every source — no cross-source dedup', () async {
      final source = CombinedAccommodationSource([
        _FakeSource(
          'expedia',
          listings: [_listing(id: 'e1', sourceKey: 'expedia')],
        ),
        _FakeSource(
          'booking',
          // Same name/price as a real "resold by multiple OTAs" hotel would
          // have — deliberately still expected as a second, separate row.
          listings: [_listing(id: 'b1', sourceKey: 'booking')],
        ),
      ]);

      final result = await source.search(_query());

      expect(result.listings, hasLength(2));
      expect(result.listings.map((l) => l.sourceKey), ['expedia', 'booking']);
      expect(result.failedSourceKeys, isEmpty);
    });

    test(
      'a failing source is excluded but does not affect other sources\' results',
      () async {
        final source = CombinedAccommodationSource([
          _FakeSource(
            'expedia',
            error: const _FakeSourceException('network down'),
          ),
          _FakeSource(
            'airbnb',
            listings: [_listing(id: 'a1', sourceKey: 'airbnb')],
          ),
        ]);

        final result = await source.search(_query());

        expect(result.listings, hasLength(1));
        expect(result.listings.single.sourceKey, 'airbnb');
        expect(result.failedSourceKeys, ['expedia']);
      },
    );

    test(
      'all sources failing returns an empty result, not a thrown error',
      () async {
        final source = CombinedAccommodationSource([
          _FakeSource('expedia', error: const _FakeSourceException('down')),
          _FakeSource('booking', error: const _FakeSourceException('down')),
        ]);

        final result = await source.search(_query());

        expect(result.listings, isEmpty);
        expect(
          result.failedSourceKeys,
          unorderedEquals(['expedia', 'booking']),
        );
      },
    );

    test('queries every source in parallel, not sequentially', () async {
      final stopwatch = Stopwatch()..start();
      final source = CombinedAccommodationSource([
        _FakeSource('a', delay: const Duration(milliseconds: 150)),
        _FakeSource('b', delay: const Duration(milliseconds: 150)),
        _FakeSource('c', delay: const Duration(milliseconds: 150)),
      ]);

      await source.search(_query());
      stopwatch.stop();

      // Sequential would take ~450ms; parallel should be close to 150ms.
      // Generous upper bound to avoid CI flakiness while still catching a
      // regression to sequential fetching.
      expect(stopwatch.elapsedMilliseconds, lessThan(350));
    });

    test('re-applies the search radius authoritatively', () async {
      // ~3km east of the query center — outside a 2km radius.
      final farListing = _listing(
        id: 'far',
        sourceKey: 'expedia',
        longitude: 11.03,
      );
      final nearListing = _listing(
        id: 'near',
        sourceKey: 'expedia',
        longitude: 10.9920,
      );
      final source = CombinedAccommodationSource([
        _FakeSource('expedia', listings: [farListing, nearListing]),
      ]);

      final result = await source.search(_query());

      expect(result.listings.map((l) => l.id), ['near']);
    });

    test('re-applies min/max price authoritatively', () async {
      final source = CombinedAccommodationSource([
        _FakeSource(
          'expedia',
          listings: [
            _listing(id: 'cheap', sourceKey: 'expedia', pricePerNight: 20),
            _listing(id: 'mid', sourceKey: 'expedia'),
            _listing(id: 'expensive', sourceKey: 'expedia', pricePerNight: 400),
          ],
        ),
      ]);

      final result = await source.search(
        _query(minPricePerNight: 50, maxPricePerNight: 200),
      );

      expect(result.listings.map((l) => l.id), ['mid']);
    });

    test('an empty sources list returns an empty result', () async {
      final source = CombinedAccommodationSource(const []);

      final result = await source.search(_query());

      expect(result.listings, isEmpty);
      expect(result.failedSourceKeys, isEmpty);
    });
  });
}
