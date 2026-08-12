import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/weather/fallback_weather_service.dart';
import 'package:kumo_claude/core/weather/weather_condition.dart';
import 'package:kumo_claude/core/weather/weather_forecast.dart';
import 'package:kumo_claude/core/weather/weather_service.dart';

class _StubWeatherService implements WeatherService {
  _StubWeatherService({this.result, this.error});

  final WeatherForecast? result;
  final Exception? error;
  int callCount = 0;

  @override
  Future<WeatherForecast?> forecastFor({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    callCount++;
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

WeatherForecast _forecast(String sourceName) => WeatherForecast(
  forecastFor: DateTime(2026, 6),
  temperatureCelsius: 20,
  condition: WeatherCondition.clear,
  conditionDescription: 'Clear sky',
  sourceName: sourceName,
);

void main() {
  test('returns the first source that answers with non-null', () async {
    final first = _StubWeatherService(result: _forecast('First'));
    final second = _StubWeatherService(result: _forecast('Second'));
    final service = FallbackWeatherService([first, second]);

    final result = await service.forecastFor(
      latitude: 0,
      longitude: 0,
      date: DateTime(2026, 6),
    );

    expect(result?.sourceName, 'First');
    expect(second.callCount, 0);
  });

  test('falls through to the next source when one returns null', () async {
    final first = _StubWeatherService();
    final second = _StubWeatherService(result: _forecast('Second'));
    final service = FallbackWeatherService([first, second]);

    final result = await service.forecastFor(
      latitude: 0,
      longitude: 0,
      date: DateTime(2026, 6),
    );

    expect(result?.sourceName, 'Second');
  });

  test('falls through to the next source when one throws', () async {
    final first = _StubWeatherService(error: Exception('network down'));
    final second = _StubWeatherService(result: _forecast('Second'));
    final service = FallbackWeatherService([first, second]);

    final result = await service.forecastFor(
      latitude: 0,
      longitude: 0,
      date: DateTime(2026, 6),
    );

    expect(result?.sourceName, 'Second');
  });

  test('returns null when every source is exhausted', () async {
    final first = _StubWeatherService();
    final second = _StubWeatherService(error: Exception('boom'));
    final service = FallbackWeatherService([first, second]);

    final result = await service.forecastFor(
      latitude: 0,
      longitude: 0,
      date: DateTime(2026, 6),
    );

    expect(result, isNull);
  });
}
