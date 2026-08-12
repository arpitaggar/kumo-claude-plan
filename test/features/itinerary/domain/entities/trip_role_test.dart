import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_role.dart';

void main() {
  group('resolveTripRole', () {
    test('returns captain when userId matches ownerId', () {
      final role = resolveTripRole(
        ownerId: 'owner-1',
        memberUserIds: const ['member-1'],
        userId: 'owner-1',
      );
      expect(role, TripRole.captain);
    });

    test('returns crew when userId is in memberUserIds', () {
      final role = resolveTripRole(
        ownerId: 'owner-1',
        memberUserIds: const ['member-1', 'member-2'],
        userId: 'member-2',
      );
      expect(role, TripRole.crew);
    });

    test('returns hitchhiker when isHitchhikerContext is true, regardless '
        'of userId', () {
      final role = resolveTripRole(
        ownerId: 'owner-1',
        memberUserIds: const [],
        isHitchhikerContext: true,
      );
      expect(role, TripRole.hitchhiker);
    });

    test('defaults to crew (never captain) for an unrecognized identity', () {
      final role = resolveTripRole(
        ownerId: 'owner-1',
        memberUserIds: const ['member-1'],
        userId: 'stranger',
      );
      expect(role, TripRole.crew);
    });
  });

  group('isHitchhiker', () {
    test('is true only for TripRole.hitchhiker', () {
      expect(isHitchhiker(TripRole.hitchhiker), isTrue);
      expect(isHitchhiker(TripRole.captain), isFalse);
      expect(isHitchhiker(TripRole.crew), isFalse);
    });
  });
}
