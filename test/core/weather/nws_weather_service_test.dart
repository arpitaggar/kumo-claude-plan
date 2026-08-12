import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kumo_claude/core/weather/nws_weather_service.dart';
import 'package:kumo_claude/core/weather/weather_condition.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient client;
  late NwsWeatherService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    client = _MockHttpClient();
    service = NwsWeatherService(client: client);
  });

  void stubPoints(http.Response response) {
    when(
      () => client.get(
        any(that: predicate<Uri>((u) => u.path.startsWith('/points/'))),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async => response);
  }

  void stubForecast(http.Response response) {
    when(
      () => client.get(
        any(that: predicate<Uri>((u) => u.path.contains('/gridpoints/'))),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async => response);
  }

  group('forecastFor', () {
    test(
      'returns null when the location is outside the US grid (404)',
      () async {
        stubPoints(http.Response('not found', 404));

        final result = await service.forecastFor(
          latitude: 48.1351,
          longitude: 11.5820,
          date: DateTime(2026, 6),
        );

        expect(result, isNull);
      },
    );

    test('throws for an unexpected points status code', () async {
      stubPoints(http.Response('server error', 500));

      expect(
        () => service.forecastFor(
          latitude: 39,
          longitude: -95,
          date: DateTime(2026, 6),
        ),
        throwsException,
      );
    });

    test('combines the day and night periods for the requested date', () async {
      stubPoints(
        http.Response(
          jsonEncode({
            'properties': {
              'forecast': 'https://api.weather.gov/gridpoints/TOP/1,1/forecast',
            },
          }),
          200,
        ),
      );
      stubForecast(
        http.Response(
          jsonEncode({
            'properties': {
              'periods': [
                {
                  'startTime': '2026-06-01T06:00:00-04:00',
                  'isDaytime': true,
                  'temperature': 77,
                  'temperatureUnit': 'F',
                  'probabilityOfPrecipitation': {'value': 20},
                  'windSpeed': '10 mph',
                  'shortForecast': 'Partly Sunny',
                },
                {
                  'startTime': '2026-06-01T18:00:00-04:00',
                  'isDaytime': false,
                  'temperature': 59,
                  'temperatureUnit': 'F',
                  'probabilityOfPrecipitation': {'value': 10},
                  'windSpeed': '5 mph',
                  'shortForecast': 'Clear',
                },
                {
                  'startTime': '2026-06-02T06:00:00-04:00',
                  'isDaytime': true,
                  'temperature': 80,
                  'temperatureUnit': 'F',
                  'probabilityOfPrecipitation': {'value': 0},
                  'windSpeed': '5 mph',
                  'shortForecast': 'Sunny',
                },
              ],
            },
          }),
          200,
        ),
      );

      final result = await service.forecastFor(
        latitude: 39,
        longitude: -95,
        date: DateTime(2026, 6),
      );

      expect(result, isNotNull);
      expect(result!.sourceName, 'US National Weather Service');
      expect(result.condition, WeatherCondition.partlyCloudy);
      expect(result.temperatureMaxCelsius, closeTo(25, 0.1));
      expect(result.temperatureMinCelsius, closeTo(15, 0.1));
      expect(result.precipitationProbabilityPercent, 20);
      expect(result.windSpeedKmh, closeTo(16.09, 0.1));
    });

    test('returns null when no period matches the requested date', () async {
      stubPoints(
        http.Response(
          jsonEncode({
            'properties': {
              'forecast': 'https://api.weather.gov/gridpoints/TOP/1,1/forecast',
            },
          }),
          200,
        ),
      );
      stubForecast(
        http.Response(
          jsonEncode({
            'properties': {
              'periods': [
                {
                  'startTime': '2026-06-05T06:00:00-04:00',
                  'isDaytime': true,
                  'temperature': 80,
                  'temperatureUnit': 'F',
                  'shortForecast': 'Sunny',
                },
              ],
            },
          }),
          200,
        ),
      );

      final result = await service.forecastFor(
        latitude: 39,
        longitude: -95,
        date: DateTime(2026, 6),
      );

      expect(result, isNull);
    });
  });
}
