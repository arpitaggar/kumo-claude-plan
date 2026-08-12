import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/weather/weather_condition.dart';
import 'package:kumo_claude/core/weather/weather_forecast.dart';

void main() {
  WeatherForecast forecast({double temperatureCelsius = 20}) => WeatherForecast(
    forecastFor: DateTime(2026, 6),
    temperatureCelsius: temperatureCelsius,
    condition: WeatherCondition.clear,
    conditionDescription: 'Clear sky',
    sourceName: 'Open-Meteo',
  );

  test('two forecasts with identical fields are equal', () {
    expect(forecast(), forecast());
  });

  test('forecasts differing by one field are not equal', () {
    expect(forecast(), isNot(forecast(temperatureCelsius: 21)));
  });
}
