import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kumo_claude/core/weather/open_meteo_weather_service.dart';
import 'package:kumo_claude/core/weather/weather_condition.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient client;
  late OpenMeteoWeatherService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    client = _MockHttpClient();
    service = OpenMeteoWeatherService(client: client);
  });

  test('throws for a non-200 response', () async {
    when(
      () => client.get(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) async => http.Response('error', 500));

    expect(
      () => service.forecastFor(
        latitude: 13.7563,
        longitude: 100.5018,
        date: DateTime(2026, 6, 1),
      ),
      throwsException,
    );
  });

  test(
    'returns null when the requested date is outside the response',
    () async {
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'daily': {
              'time': ['2026-06-05'],
              'weathercode': [0],
              'temperature_2m_max': [30],
              'temperature_2m_min': [22],
              'precipitation_probability_max': [0],
              'windspeed_10m_max': [10],
            },
          }),
          200,
        ),
      );

      final result = await service.forecastFor(
        latitude: 13.7563,
        longitude: 100.5018,
        date: DateTime(2026, 6, 1),
      );

      expect(result, isNull);
    },
  );

  test('maps the matching day into a WeatherForecast', () async {
    when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'daily': {
            'time': ['2026-05-31', '2026-06-01', '2026-06-02'],
            'weathercode': [3, 61, 0],
            'temperature_2m_max': [29, 26, 30],
            'temperature_2m_min': [23, 21, 24],
            'precipitation_probability_max': [10, 80, 0],
            'windspeed_10m_max': [12, 18, 9],
          },
        }),
        200,
      ),
    );

    final result = await service.forecastFor(
      latitude: 13.7563,
      longitude: 100.5018,
      date: DateTime(2026, 6, 1),
    );

    expect(result, isNotNull);
    expect(result!.sourceName, 'Open-Meteo');
    expect(result.condition, WeatherCondition.rain);
    expect(result.conditionDescription, 'Rain');
    expect(result.temperatureMaxCelsius, 26);
    expect(result.temperatureMinCelsius, 21);
    expect(result.precipitationProbabilityPercent, 80);
    expect(result.windSpeedKmh, 18);
  });
}
