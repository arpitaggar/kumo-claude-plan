import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kumo_claude/core/routing/osrm_routing_service.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient client;
  late OsrmRoutingService service;

  const origin = Waypoint(
    name: 'Chiang Mai',
    latitude: 18.7883,
    longitude: 98.9853,
  );
  const destination = Waypoint(
    name: 'Pai',
    latitude: 19.3583,
    longitude: 98.4400,
  );

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    client = _MockHttpClient();
    service = OsrmRoutingService(client: client);
  });

  http.Response okResponse(List<List<double>> coordinates) => http.Response(
    jsonEncode({
      'code': 'Ok',
      'routes': [
        {
          'geometry': {'type': 'LineString', 'coordinates': coordinates},
        },
      ],
    }),
    200,
  );

  group('route', () {
    test('requests the driving profile for car/motorcycle/bus', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => okResponse([
          [98.9853, 18.7883],
          [98.4400, 19.3583],
        ]),
      );

      for (final mode in [
        TransportMode.car,
        TransportMode.motorcycle,
        TransportMode.bus,
      ]) {
        final captured = <Uri>[];
        when(() => client.get(any())).thenAnswer((invocation) async {
          captured.add(invocation.positionalArguments.single as Uri);
          return okResponse([
            [98.9853, 18.7883],
            [98.4400, 19.3583],
          ]);
        });

        await service.route(
          origin: origin,
          destination: destination,
          mode: mode,
        );

        expect(
          captured.single.path,
          '/route/v1/driving/98.9853,18.7883;98.44,19.3583',
        );
      }
    });

    test('requests the foot profile for walk', () async {
      final captured = <Uri>[];
      when(() => client.get(any())).thenAnswer((invocation) async {
        captured.add(invocation.positionalArguments.single as Uri);
        return okResponse([
          [98.9853, 18.7883],
          [98.4400, 19.3583],
        ]);
      });

      await service.route(
        origin: origin,
        destination: destination,
        mode: TransportMode.walk,
      );

      expect(
        captured.single.path,
        '/route/v1/foot/98.9853,18.7883;98.44,19.3583',
      );
    });

    test(
      'returns null without a network call for a non-routable mode',
      () async {
        final result = await service.route(
          origin: origin,
          destination: destination,
          mode: TransportMode.flight,
        );

        expect(result, isNull);
        verifyNever(() => client.get(any()));
      },
    );

    test('flips GeoJSON [lng, lat] coordinates to (lat, lng) points', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => okResponse([
          [98.9853, 18.7883],
          [98.7, 19.0],
          [98.4400, 19.3583],
        ]),
      );

      final result = await service.route(
        origin: origin,
        destination: destination,
        mode: TransportMode.car,
      );

      expect(result, [(18.7883, 98.9853), (19.0, 98.7), (19.3583, 98.4400)]);
    });

    test('returns null on a non-200 response', () async {
      when(
        () => client.get(any()),
      ).thenAnswer((_) async => http.Response('Server error', 500));

      final result = await service.route(
        origin: origin,
        destination: destination,
        mode: TransportMode.car,
      );

      expect(result, isNull);
    });

    test('returns null when the response code is not "Ok"', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'code': 'NoRoute', 'routes': <dynamic>[]}),
          200,
        ),
      );

      final result = await service.route(
        origin: origin,
        destination: destination,
        mode: TransportMode.walk,
      );

      expect(result, isNull);
    });

    test('returns null on a malformed body instead of throwing', () async {
      when(
        () => client.get(any()),
      ).thenAnswer((_) async => http.Response('not json', 200));

      final result = await service.route(
        origin: origin,
        destination: destination,
        mode: TransportMode.car,
      );

      expect(result, isNull);
    });
  });
}
