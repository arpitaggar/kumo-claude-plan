import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kumo_claude/core/weather/met_norway_weather_service.dart';
import 'package:kumo_claude/core/weather/weather_condition.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

Map<String, dynamic> _entry(
  String time, {
  double? temp,
  double? windSpeed,
  String? symbolCode,
}) {
  return {
    'time': time,
    'data': {
      'instant': {
        'details': {
          if (temp != null) 'air_temperature': temp,
          if (windSpeed != null) 'wind_speed': windSpeed,
        },
      },
      if (symbolCode != null)
        'next_6_hours': {
          'summary': {'symbol_code': symbolCode},
        },
    },
  };
}

void main() {
  late _MockHttpClient client;
  late MetNorwayWeatherService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    client = _MockHttpClient();
    service = MetNorwayWeatherService(client: client);
  });

  test('throws for a non-200 response', () async {
    when(
      () => client.get(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) async => http.Response('error', 500));

    expect(
      () => service.forecastFor(
        latitude: 59.9,
        longitude: 10.7,
        date: DateTime(2026, 6, 1),
      ),
      throwsException,
    );
  });

  test(
    'returns null when no timeseries entry falls on the requested date',
    () async {
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'properties': {
              'timeseries': [_entry('2026-06-05T12:00:00Z', temp: 15)],
            },
          }),
          200,
        ),
      );

      final result = await service.forecastFor(
        latitude: 59.9,
        longitude: 10.7,
        date: DateTime(2026, 6, 1),
      );

      expect(result, isNull);
    },
  );

  test('aggregates same-day entries into min/max temp and uses the midday '
      'entry for condition/wind', () async {
    when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'properties': {
            'timeseries': [
              _entry(
                '2026-06-01T00:00:00Z',
                temp: 10,
                symbolCode: 'clearsky_night',
              ),
              _entry(
                '2026-06-01T06:00:00Z',
                temp: 14,
                symbolCode: 'partlycloudy_day',
              ),
              _entry(
                '2026-06-01T12:00:00Z',
                temp: 18,
                windSpeed: 4,
                symbolCode: 'cloudy',
              ),
              _entry(
                '2026-06-01T18:00:00Z',
                temp: 12,
                symbolCode: 'lightrainshowers_day',
              ),
              _entry('2026-06-02T00:00:00Z', temp: 99),
            ],
          },
        }),
        200,
      ),
    );

    final result = await service.forecastFor(
      latitude: 59.9,
      longitude: 10.7,
      date: DateTime(2026, 6, 1),
    );

    expect(result, isNotNull);
    expect(result!.sourceName, 'MET Norway');
    expect(result.temperatureMinCelsius, 10);
    expect(result.temperatureMaxCelsius, 18);
    expect(result.temperatureCelsius, closeTo(13.5, 0.01));
    expect(result.condition, WeatherCondition.cloudy);
    expect(result.windSpeedKmh, closeTo(14.4, 0.01));
  });
}
