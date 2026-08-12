import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fallback_weather_service.dart';
import 'met_norway_weather_service.dart';
import 'nws_weather_service.dart';
import 'open_meteo_weather_service.dart';
import 'weather_forecast.dart';
import 'weather_service.dart';

/// Source priority: US National Weather Service (official, US-only) ->
/// MET Norway (official, global) -> Open-Meteo (generic, global safety
/// net). This list is the single place that defines the fallback order —
/// see fallback_weather_service.dart.
final weatherServiceProvider = Provider<WeatherService>(
  (ref) => FallbackWeatherService([
    NwsWeatherService(),
    MetNorwayWeatherService(),
    OpenMeteoWeatherService(),
  ]),
);

/// Family key for [segmentWeatherProvider] — a location rounded to ~100m
/// precision plus a date-only [date], so repeated widget rebuilds for the
/// same leg reuse Riverpod's own cached result instead of refetching.
class WeatherRequest extends Equatable {
  WeatherRequest({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) : latitude = double.parse(latitude.toStringAsFixed(3)),
       longitude = double.parse(longitude.toStringAsFixed(3)),
       date = DateTime(date.year, date.month, date.day);

  final double latitude;
  final double longitude;
  final DateTime date;

  @override
  List<Object> get props => [latitude, longitude, date];
}

final segmentWeatherProvider =
    FutureProvider.family<WeatherForecast?, WeatherRequest>(
      (ref, request) => ref
          .watch(weatherServiceProvider)
          .forecastFor(
            latitude: request.latitude,
            longitude: request.longitude,
            date: request.date,
          ),
    );
