import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kumo_claude/core/routing/google_directions_routing_service.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient client;
  late GoogleDirectionsRoutingService service;

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
    service = GoogleDirectionsRoutingService(
      client: client,
      apiKey: 'test-key',
    );
  });

  // Encodes [(38.5,-120.2), (40.7,-120.95), (43.252,-126.453)] — the
  // worked example from Google's own polyline-algorithm documentation.
  const sampleEncodedPolyline = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

  http.Response okResponse(String encodedPolyline) => http.Response(
    jsonEncode({
      'status': 'OK',
      'routes': [
        {
          'overview_polyline': {'points': encodedPolyline},
        },
      ],
    }),
    200,
  );

  group('route', () {
    test(
      'returns null without a network call when no API key is configured',
      () async {
        final noKeyService = GoogleDirectionsRoutingService(
          client: client,
          apiKey: '',
        );

        final result = await noKeyService.route(
          origin: origin,
          destination: destination,
          mode: TransportMode.car,
        );

        expect(result, isNull);
        verifyNever(() => client.get(any()));
      },
    );

    test(
      'returns null without a network call for a non-routable mode',
      () async {
        final result = await service.route(
          origin: origin,
          destination: destination,
          mode: TransportMode.ferry,
        );

        expect(result, isNull);
        verifyNever(() => client.get(any()));
      },
    );

    test(
      'requests driving mode for car/motorcycle/bus and walking for walk',
      () async {
        for (final entry in {
          TransportMode.car: 'driving',
          TransportMode.motorcycle: 'driving',
          TransportMode.bus: 'driving',
          TransportMode.walk: 'walking',
        }.entries) {
          final captured = <Uri>[];
          when(() => client.get(any())).thenAnswer((invocation) async {
            captured.add(invocation.positionalArguments.single as Uri);
            return okResponse(sampleEncodedPolyline);
          });

          await service.route(
            origin: origin,
            destination: destination,
            mode: entry.key,
          );

          expect(captured.single.queryParameters['mode'], entry.value);
          expect(captured.single.queryParameters['key'], 'test-key');
          expect(
            captured.single.queryParameters['origin'],
            '${origin.latitude},${origin.longitude}',
          );
        }
      },
    );

    test('decodes the overview polyline into (lat, lng) points', () async {
      when(
        () => client.get(any()),
      ).thenAnswer((_) async => okResponse(sampleEncodedPolyline));

      final result = await service.route(
        origin: origin,
        destination: destination,
        mode: TransportMode.car,
      );

      expect(result, isNotNull);
      expect(result, hasLength(3));
      expect(result![0].$1, closeTo(38.5, 0.0001));
      expect(result[0].$2, closeTo(-120.2, 0.0001));
      expect(result[2].$1, closeTo(43.252, 0.0001));
      expect(result[2].$2, closeTo(-126.453, 0.0001));
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

    test('returns null when status is not "OK"', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'status': 'ZERO_RESULTS', 'routes': <dynamic>[]}),
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
