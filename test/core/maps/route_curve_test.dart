import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/maps/route_curve.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';

void main() {
  const munich = Waypoint(name: 'Munich', latitude: 48.1351, longitude: 11.5820);
  const bangkok =
      Waypoint(name: 'Bangkok', latitude: 13.7563, longitude: 100.5018);
  const chiangMai =
      Waypoint(name: 'Chiang Mai', latitude: 18.7883, longitude: 98.9853);
  const pai = Waypoint(name: 'Pai', latitude: 19.3583, longitude: 98.4400);

  TripSegment segment(String id, Waypoint origin, Waypoint destination) =>
      TripSegment(
        id: id,
        itineraryId: 'it-1',
        orderIndex: 0,
        mode: TransportMode.flight,
        origin: origin,
        destination: destination,
      );

  group('sameWaypoint', () {
    test('true for identical coordinates', () {
      expect(sameWaypoint(munich, munich), isTrue);
    });

    test('true for coordinates within the epsilon', () {
      const nearMunich =
          Waypoint(name: 'Munich (2nd search)', latitude: 48.15, longitude: 11.60);
      expect(sameWaypoint(munich, nearMunich), isTrue);
    });

    test('false for genuinely different places', () {
      expect(sameWaypoint(munich, bangkok), isFalse);
    });
  });

  group('hasReverseLeg', () {
    test('false for a single one-way leg', () {
      final segments = [segment('a', munich, bangkok)];
      expect(hasReverseLeg(segments, segments[0]), isFalse);
    });

    test('true when a reverse leg exists elsewhere in the trip', () {
      final segments = [
        segment('out', chiangMai, pai),
        segment('back', pai, chiangMai),
      ];
      expect(hasReverseLeg(segments, segments[0]), isTrue);
      expect(hasReverseLeg(segments, segments[1]), isTrue);
    });

    test('false for unrelated legs between different places', () {
      final segments = [
        segment('a', munich, bangkok),
        segment('b', bangkok, chiangMai),
        segment('c', chiangMai, pai),
      ];
      for (final s in segments) {
        expect(hasReverseLeg(segments, s), isFalse);
      }
    });

    test('a segment never matches itself as its own reverse', () {
      // A degenerate same-place segment (origin == destination) shouldn't
      // report a reverse leg against itself.
      final segments = [segment('a', munich, munich)];
      expect(hasReverseLeg(segments, segments[0]), isFalse);
    });

    test('detects the reverse leg even with slightly different geocoded '
        'coordinates for "the same" place', () {
      const chiangMaiSecondSearch = Waypoint(
        name: 'Chiang Mai, Thailand',
        latitude: 18.80,
        longitude: 98.98,
      );
      const paiSecondSearch =
          Waypoint(name: 'Pai, Thailand', latitude: 19.36, longitude: 98.44);
      final segments = [
        segment('out', chiangMai, pai),
        segment('back', paiSecondSearch, chiangMaiSecondSearch),
      ];
      expect(hasReverseLeg(segments, segments[0]), isTrue);
    });
  });

  group('curvedPath', () {
    test('returns exactly the 2 endpoints when not curved', () {
      final path = curvedPath(
        startLat: munich.latitude,
        startLng: munich.longitude,
        endLat: bangkok.latitude,
        endLng: bangkok.longitude,
        curved: false,
      );
      expect(path, [
        (munich.latitude, munich.longitude),
        (bangkok.latitude, bangkok.longitude),
      ]);
    });

    test('returns more than 2 points when curved', () {
      final path = curvedPath(
        startLat: chiangMai.latitude,
        startLng: chiangMai.longitude,
        endLat: pai.latitude,
        endLng: pai.longitude,
        curved: true,
      );
      expect(path.length, greaterThan(2));
    });

    test('curved path starts and ends at the requested endpoints', () {
      final path = curvedPath(
        startLat: chiangMai.latitude,
        startLng: chiangMai.longitude,
        endLat: pai.latitude,
        endLng: pai.longitude,
        curved: true,
      );
      expect(path.first.$1, closeTo(chiangMai.latitude, 1e-9));
      expect(path.first.$2, closeTo(chiangMai.longitude, 1e-9));
      expect(path.last.$1, closeTo(pai.latitude, 1e-9));
      expect(path.last.$2, closeTo(pai.longitude, 1e-9));
    });

    test('curved path bows away from the straight line', () {
      final path = curvedPath(
        startLat: chiangMai.latitude,
        startLng: chiangMai.longitude,
        endLat: pai.latitude,
        endLng: pai.longitude,
        curved: true,
      );
      final midpoint = path[path.length ~/ 2];
      final straightMidLat = (chiangMai.latitude + pai.latitude) / 2;
      final straightMidLng = (chiangMai.longitude + pai.longitude) / 2;
      final deviation = (midpoint.$1 - straightMidLat).abs() +
          (midpoint.$2 - straightMidLng).abs();
      expect(deviation, greaterThan(0.001));
    });

    test('reversing start/end bows to the opposite side of the line', () {
      final outbound = curvedPath(
        startLat: chiangMai.latitude,
        startLng: chiangMai.longitude,
        endLat: pai.latitude,
        endLng: pai.longitude,
        curved: true,
      );
      final returnLeg = curvedPath(
        startLat: pai.latitude,
        startLng: pai.longitude,
        endLat: chiangMai.latitude,
        endLng: chiangMai.longitude,
        curved: true,
      );

      final straightMidLat = (chiangMai.latitude + pai.latitude) / 2;
      final straightMidLng = (chiangMai.longitude + pai.longitude) / 2;

      final outMid = outbound[outbound.length ~/ 2];
      final backMid = returnLeg[returnLeg.length ~/ 2];

      // Both bow away from the straight-line midpoint, but in opposite
      // directions — their offsets from that midpoint should point roughly
      // opposite ways (negative dot product).
      final outOffsetLat = outMid.$1 - straightMidLat;
      final outOffsetLng = outMid.$2 - straightMidLng;
      final backOffsetLat = backMid.$1 - straightMidLat;
      final backOffsetLng = backMid.$2 - straightMidLng;

      final dot = outOffsetLat * backOffsetLat + outOffsetLng * backOffsetLng;
      expect(dot, lessThan(0));
    });

    test('does not throw for identical start/end points', () {
      final path = curvedPath(
        startLat: munich.latitude,
        startLng: munich.longitude,
        endLat: munich.latitude,
        endLng: munich.longitude,
        curved: true,
      );
      expect(path, isNotEmpty);
    });
  });
}
