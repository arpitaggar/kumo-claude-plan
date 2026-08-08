import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_email_alias.dart';

void main() {
  test('address joins localPart and domain with @', () {
    const alias = TripEmailAlias(
      itineraryId: 'it-1',
      localPart: 'trip-x7k2m9qz',
      domain: 'trips.kumo.app',
    );

    expect(alias.address, 'trip-x7k2m9qz@trips.kumo.app');
  });

  test('two aliases with the same fields are equal', () {
    const a = TripEmailAlias(
      itineraryId: 'it-1',
      localPart: 'trip-x7k2m9qz',
      domain: 'trips.kumo.app',
    );
    const b = TripEmailAlias(
      itineraryId: 'it-1',
      localPart: 'trip-x7k2m9qz',
      domain: 'trips.kumo.app',
    );

    expect(a, b);
  });
}
