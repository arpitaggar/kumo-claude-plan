import 'package:equatable/equatable.dart';

import 'weather_condition.dart';

/// A single day's forecast for one location, as returned by a
/// [WeatherService]. Kept daily-only (no hourly breakdown) since the three
/// sources behind [WeatherService] have very different native granularity
/// (NWS: day/night periods, MET Norway: hourly timeseries, Open-Meteo:
/// native daily) — daily is the shape all three can produce consistently.
class WeatherForecast extends Equatable {
  const WeatherForecast({
    required this.forecastFor,
    required this.temperatureCelsius,
    required this.condition,
    required this.conditionDescription,
    required this.sourceName,
    this.temperatureMinCelsius,
    this.temperatureMaxCelsius,
    this.precipitationProbabilityPercent,
    this.windSpeedKmh,
  });

  /// The calendar date this forecast is for (date-only; time-of-day and
  /// timezone are not meaningful here since sources disagree on both).
  final DateTime forecastFor;

  /// Representative temperature for the day — the max/day temperature where
  /// a source distinguishes day/night, otherwise the single value reported.
  final double temperatureCelsius;

  final double? temperatureMinCelsius;
  final double? temperatureMaxCelsius;

  final WeatherCondition condition;

  /// Short human-readable description as worded by the source (e.g. "Light
  /// rain showers"), shown alongside [condition]'s icon.
  final String conditionDescription;

  final int? precipitationProbabilityPercent;
  final double? windSpeedKmh;

  /// Attribution for the source that produced this forecast (e.g. "US
  /// National Weather Service"), shown in the UI to satisfy the free
  /// sources' terms-of-use attribution requirements.
  final String sourceName;

  @override
  List<Object?> get props => [
    forecastFor,
    temperatureCelsius,
    temperatureMinCelsius,
    temperatureMaxCelsius,
    condition,
    conditionDescription,
    precipitationProbabilityPercent,
    windSpeedKmh,
    sourceName,
  ];
}
