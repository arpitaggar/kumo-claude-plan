import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kumo_claude/core/geocoding/nominatim_geocoding_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient client;
  late NominatimGeocodingService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    client = _MockHttpClient();
    service = NominatimGeocodingService(client: client);
  });

  http.Response jsonResponse(List<Map<String, dynamic>> results) =>
      http.Response(jsonEncode(results), 200);

  group('search', () {
    test('returns an empty list without calling the network for a blank '
        'query', () async {
      final result = await service.search('   ');

      expect(result, isEmpty);
      verifyNever(() => client.get(any(), headers: any(named: 'headers')));
    });

    test('trims the query and requests the Nominatim search endpoint',
        () async {
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => jsonResponse(const []));

      await service.search('  Chiang Mai  ');

      final captured = verify(
        () => client.get(captureAny(), headers: any(named: 'headers')),
      ).captured;
      final uri = captured.single as Uri;

      expect(uri.host, 'nominatim.openstreetmap.org');
      expect(uri.path, '/search');
      expect(uri.queryParameters['q'], 'Chiang Mai');
      expect(uri.queryParameters['format'], 'jsonv2');
      expect(uri.queryParameters['limit'], '8');
    });

    test('sends a descriptive User-Agent and defaults Accept-Language to '
        '"en"', () async {
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => jsonResponse(const []));

      await service.search('Pai');

      final captured = verify(
        () => client.get(any(), headers: captureAny(named: 'headers')),
      ).captured;
      final headers = captured.single as Map<String, String>;

      expect(headers['User-Agent'], contains('KumoTravelApp'));
      expect(headers['Accept-Language'], 'en');
    });

    test('sends a custom Accept-Language when provided', () async {
      final customService = NominatimGeocodingService(
        client: client,
        acceptLanguage: 'th',
      );
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => jsonResponse(const []));

      await customService.search('Bangkok');

      final captured = verify(
        () => client.get(any(), headers: captureAny(named: 'headers')),
      ).captured;
      final headers = captured.single as Map<String, String>;

      expect(headers['Accept-Language'], 'th');
    });

    test('parses display_name/lat/lon into GeocodingResult entries',
        () async {
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
        (_) async => jsonResponse([
          {
            'display_name': 'Chiang Mai, Thailand',
            'lat': '18.7883',
            'lon': '98.9853',
          },
        ]),
      );

      final results = await service.search('Chiang Mai');

      expect(results, hasLength(1));
      expect(results.single.name, 'Chiang Mai, Thailand');
      expect(results.single.latitude, 18.7883);
      expect(results.single.longitude, 98.9853);
    });

    test('throws when the response status is not 200', () async {
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Server error', 500));

      expect(() => service.search('Munich'), throwsException);
    });

    test('throttles back-to-back requests to at least 1.1 seconds apart',
        () async {
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => jsonResponse(const []));

      final stopwatch = Stopwatch()..start();
      await service.search('Munich');
      await service.search('Bangkok');
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        greaterThanOrEqualTo(1100),
      );
    });
  });
}
