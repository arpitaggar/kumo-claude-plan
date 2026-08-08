import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/data/models/trip_segment_model.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';

void main() {
  final fullJson = <String, dynamic>{
    'id': 'seg-1',
    'itinerary_id': 'it-1',
    'order_index': 2,
    'transport_mode': 'motorcycle',
    'origin_name': 'Chiang Mai',
    'origin_lat': 18.7883,
    'origin_lng': 98.9853,
    'destination_name': 'Pai',
    'destination_lat': 19.3583,
    'destination_lng': 98.4400,
    'departure_time': '2026-06-01T08:00:00.000Z',
    'arrival_time': '2026-06-01T11:30:00.000Z',
    'notes': 'rental booked',
  };

  group('TripSegmentModel.fromJson', () {
    test('parses all fields correctly', () {
      final model = TripSegmentModel.fromJson(fullJson);

      expect(model.id, 'seg-1');
      expect(model.itineraryId, 'it-1');
      expect(model.orderIndex, 2);
      expect(model.mode, TransportMode.motorcycle);
      expect(model.origin.name, 'Chiang Mai');
      expect(model.origin.latitude, 18.7883);
      expect(model.origin.longitude, 98.9853);
      expect(model.destination.name, 'Pai');
      expect(model.destination.latitude, 19.3583);
      expect(model.destination.longitude, 98.4400);
      expect(model.departureTime, DateTime.utc(2026, 6, 1, 8));
      expect(model.arrivalTime, DateTime.utc(2026, 6, 1, 11, 30));
      expect(model.notes, 'rental booked');
    });

    test('defaults to TransportMode.other for an unknown mode', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['transport_mode'] = 'hot_air_balloon';
      final model = TripSegmentModel.fromJson(json);
      expect(model.mode, TransportMode.other);
    });

    test('defaults orderIndex to 0 when missing', () {
      final json = Map<String, dynamic>.from(fullJson)..remove('order_index');
      final model = TripSegmentModel.fromJson(json);
      expect(model.orderIndex, 0);
    });

    test('leaves departureTime/arrivalTime/notes null when absent', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..remove('departure_time')
        ..remove('arrival_time')
        ..remove('notes');
      final model = TripSegmentModel.fromJson(json);

      expect(model.departureTime, isNull);
      expect(model.arrivalTime, isNull);
      expect(model.notes, isNull);
    });

    test('parses integer lat/lng as double', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['origin_lat'] = 19
        ..['origin_lng'] = 99;
      final model = TripSegmentModel.fromJson(json);
      expect(model.origin.latitude, 19.0);
      expect(model.origin.longitude, 99.0);
    });

    test('leaves routeGeometry null when absent', () {
      final model = TripSegmentModel.fromJson(fullJson);
      expect(model.routeGeometry, isNull);
    });

    test('parses route_geometry as a list of (lat, lng) points', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['route_geometry'] = [
          [18.7883, 98.9853],
          [19.0, 98.7],
          [19.3583, 98.4400],
        ];
      final model = TripSegmentModel.fromJson(json);
      expect(model.routeGeometry, [
        (18.7883, 98.9853),
        (19.0, 98.7),
        (19.3583, 98.4400),
      ]);
    });

    test('defaults isVisible to true when absent', () {
      final model = TripSegmentModel.fromJson(fullJson);
      expect(model.isVisible, isTrue);
    });

    test('parses is_visible when present', () {
      final json = Map<String, dynamic>.from(fullJson)..['is_visible'] = false;
      final model = TripSegmentModel.fromJson(json);
      expect(model.isVisible, isFalse);
    });
  });

  group('TripSegmentModel.toJson', () {
    late TripSegmentModel model;

    setUp(() {
      model = TripSegmentModel.fromJson(fullJson);
    });

    test('serialises transport_mode as the enum name', () {
      expect(model.toJson()['transport_mode'], 'motorcycle');
    });

    test('serialises origin/destination as flat name/lat/lng fields', () {
      final json = model.toJson();
      expect(json['origin_name'], 'Chiang Mai');
      expect(json['origin_lat'], 18.7883);
      expect(json['destination_name'], 'Pai');
      expect(json['destination_lng'], 98.4400);
    });

    test('omits departure_time/arrival_time/notes when null', () {
      final withoutOptionals = TripSegmentModel.fromJson(
        Map<String, dynamic>.from(fullJson)
          ..remove('departure_time')
          ..remove('arrival_time')
          ..remove('notes'),
      );

      final json = withoutOptionals.toJson();
      expect(json.containsKey('departure_time'), isFalse);
      expect(json.containsKey('arrival_time'), isFalse);
      expect(json.containsKey('notes'), isFalse);
    });

    test('round-trip: fromJson -> toJson -> fromJson preserves data', () {
      final json1 = model.toJson();
      final model2 = TripSegmentModel.fromJson(json1);

      expect(model2.id, model.id);
      expect(model2.orderIndex, model.orderIndex);
      expect(model2.mode, model.mode);
      expect(model2.origin, model.origin);
      expect(model2.destination, model.destination);
      expect(model2.departureTime, model.departureTime);
      expect(model2.notes, model.notes);
    });

    test('omits route_geometry when null', () {
      expect(model.toJson().containsKey('route_geometry'), isFalse);
    });

    test('round-trip preserves routeGeometry', () {
      final withGeometry = TripSegmentModel.fromJson(
        Map<String, dynamic>.from(fullJson)
          ..['route_geometry'] = [
            [18.7883, 98.9853],
            [19.3583, 98.4400],
          ],
      );

      final roundTripped = TripSegmentModel.fromJson(withGeometry.toJson());

      expect(roundTripped.routeGeometry, withGeometry.routeGeometry);
    });

    test('always includes is_visible', () {
      expect(model.toJson()['is_visible'], isTrue);
    });

    test('round-trip preserves isVisible', () {
      final hidden = TripSegmentModel.fromJson(
        Map<String, dynamic>.from(fullJson)..['is_visible'] = false,
      );

      final roundTripped = TripSegmentModel.fromJson(hidden.toJson());

      expect(roundTripped.isVisible, isFalse);
    });
  });

  group('TripSegmentModel.fromEntity', () {
    test('copies every field from the domain entity', () {
      const entity = TripSegment(
        id: 'seg-2',
        itineraryId: 'it-2',
        orderIndex: 1,
        mode: TransportMode.ferry,
        origin: Waypoint(name: 'A', latitude: 1, longitude: 2),
        destination: Waypoint(name: 'B', latitude: 3, longitude: 4),
      );

      final model = TripSegmentModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.itineraryId, entity.itineraryId);
      expect(model.orderIndex, entity.orderIndex);
      expect(model.mode, entity.mode);
      expect(model.origin, entity.origin);
      expect(model.destination, entity.destination);
    });
  });
}
