import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'weather_condition.dart';
import 'weather_forecast.dart';
import 'weather_service.dart';

/// The US National Weather Service — the official met office for US
/// coordinates only. `/points/{lat},{lon}` 404s for anything outside the US
/// forecast grid, which this treats as "not covered" (returns `null`) so a
/// [FallbackWeatherService] falls through to the next source rather than
/// erroring.
class NwsWeatherService implements WeatherService {
  NwsWeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'KumoTravelApp/1.0 (com.cygnus.travelKumo)';
  static const _sourceName = 'US National Weather Service';
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  Future<WeatherForecast?> forecastFor({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    final pointsUri = Uri.https(
      'api.weather.gov',
      '/points/${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}',
    );
    final pointsResponse = await _client.get(pointsUri, headers: _headers);

    if (pointsResponse.statusCode == 404) {
      return null;
    }
    if (pointsResponse.statusCode != 200) {
      throw Exception(
        'NWS points request failed (${pointsResponse.statusCode})',
      );
    }

    final pointsBody = jsonDecode(pointsResponse.body) as Map<String, dynamic>;
    final forecastUrl =
        (pointsBody['properties'] as Map<String, dynamic>?)?['forecast']
            as String?;
    if (forecastUrl == null) {
      return null;
    }

    final forecastResponse = await _client.get(
      Uri.parse(forecastUrl),
      headers: _headers,
    );
    if (forecastResponse.statusCode != 200) {
      throw Exception(
        'NWS forecast request failed (${forecastResponse.statusCode})',
      );
    }

    final forecastBody =
        jsonDecode(forecastResponse.body) as Map<String, dynamic>;
    final periods =
        ((forecastBody['properties'] as Map<String, dynamic>)['periods']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();

    final targetDate = _dateFormat.format(date);
    final matching = periods
        .where((p) => (p['startTime'] as String).substring(0, 10) == targetDate)
        .toList();
    if (matching.isEmpty) {
      return null;
    }

    Map<String, dynamic>? dayPeriod;
    Map<String, dynamic>? nightPeriod;
    for (final period in matching) {
      if (period['isDaytime'] == true) {
        dayPeriod ??= period;
      } else {
        nightPeriod ??= period;
      }
    }
    final primary = dayPeriod ?? nightPeriod ?? matching.first;

    return WeatherForecast(
      forecastFor: date,
      temperatureCelsius: _toCelsius(primary),
      temperatureMaxCelsius: dayPeriod != null ? _toCelsius(dayPeriod) : null,
      temperatureMinCelsius: nightPeriod != null
          ? _toCelsius(nightPeriod)
          : null,
      condition: _mapCondition(primary['shortForecast'] as String? ?? ''),
      conditionDescription: primary['shortForecast'] as String? ?? '',
      precipitationProbabilityPercent:
          (primary['probabilityOfPrecipitation']
                  as Map<String, dynamic>?)?['value']
              as int?,
      windSpeedKmh: _parseWindSpeedKmh(primary['windSpeed'] as String?),
      sourceName: _sourceName,
    );
  }

  static Map<String, String> get _headers => const {
    'User-Agent': _userAgent,
    'Accept': 'application/geo+json',
  };

  static double _toCelsius(Map<String, dynamic> period) {
    final value = (period['temperature'] as num).toDouble();
    final unit = period['temperatureUnit'] as String? ?? 'F';
    return unit == 'C' ? value : (value - 32) * 5 / 9;
  }

  static WeatherCondition _mapCondition(String shortForecast) {
    final text = shortForecast.toLowerCase();
    if (text.contains('thunderstorm') || text.contains('storm')) {
      return WeatherCondition.thunderstorm;
    }
    if (text.contains('snow') ||
        text.contains('flurries') ||
        text.contains('sleet') ||
        text.contains('blizzard')) {
      return WeatherCondition.snow;
    }
    if (text.contains('drizzle')) {
      return WeatherCondition.drizzle;
    }
    if (text.contains('rain') || text.contains('shower')) {
      return WeatherCondition.rain;
    }
    if (text.contains('fog') ||
        text.contains('mist') ||
        text.contains('haze')) {
      return WeatherCondition.fog;
    }
    if (text.contains('partly') ||
        text.contains('mostly sunny') ||
        text.contains('mostly clear')) {
      return WeatherCondition.partlyCloudy;
    }
    if (text.contains('cloudy') || text.contains('overcast')) {
      return WeatherCondition.cloudy;
    }
    if (text.contains('clear') || text.contains('sunny')) {
      return WeatherCondition.clear;
    }
    return WeatherCondition.unknown;
  }

  static double? _parseWindSpeedKmh(String? windSpeed) {
    if (windSpeed == null) {
      return null;
    }
    final matches = RegExp(r'\d+').allMatches(windSpeed).toList();
    if (matches.isEmpty) {
      return null;
    }
    final mph = matches.length > 1
        ? (int.parse(matches[0].group(0)!) + int.parse(matches[1].group(0)!)) /
              2
        : int.parse(matches[0].group(0)!).toDouble();
    return mph * 1.60934;
  }
}
