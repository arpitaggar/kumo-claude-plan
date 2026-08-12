import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nws_weather_service.dart' show NwsWeatherService;
import 'weather_condition.dart';
import 'weather_forecast.dart';
import 'weather_service.dart';

/// Norway's national meteorological institute — genuinely global coverage
/// (this is the data behind Yr and many other consumer apps worldwide), so
/// it stands in as the "official met office" source for every location the
/// US-only [NwsWeatherService] doesn't cover.
///
/// Their usage policy requires a descriptive User-Agent (same requirement
/// as Nominatim — see nws_weather_service.dart / nominatim_geocoding_service.dart),
/// otherwise requests are rejected.
class MetNorwayWeatherService implements WeatherService {
  MetNorwayWeatherService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'KumoTravelApp/1.0 (com.cygnus.travelKumo)';
  static const _sourceName = 'MET Norway';

  @override
  Future<WeatherForecast?> forecastFor({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    final uri = Uri.https(
      'api.met.no',
      '/weatherapi/locationforecast/2.0/compact',
      {'lat': latitude.toStringAsFixed(4), 'lon': longitude.toStringAsFixed(4)},
    );
    final response = await _client.get(
      uri,
      headers: const {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) {
      throw Exception('MET Norway request failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final timeseries =
        ((body['properties'] as Map<String, dynamic>)['timeseries']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();

    // MET Norway has no concept of a location's local timezone, so entries
    // are bucketed by their UTC calendar date — the same convention [date]
    // is treated under everywhere in this module.
    final sameDay = timeseries.where((entry) {
      final time = DateTime.parse(entry['time'] as String);
      return time.year == date.year &&
          time.month == date.month &&
          time.day == date.day;
    }).toList();
    if (sameDay.isEmpty) {
      return null;
    }

    final temps = <double>[];
    Map<String, dynamic>? middayEntry;
    int? middayDelta;
    for (final entry in sameDay) {
      final time = DateTime.parse(entry['time'] as String);
      final instant =
          (entry['data'] as Map<String, dynamic>)['instant']
              as Map<String, dynamic>?;
      final temp =
          (instant?['details'] as Map<String, dynamic>?)?['air_temperature']
              as num?;
      if (temp != null) {
        temps.add(temp.toDouble());
      }

      final delta = (time.hour - 12).abs();
      if (middayDelta == null || delta < middayDelta) {
        middayDelta = delta;
        middayEntry = entry;
      }
    }
    if (temps.isEmpty) {
      return null;
    }

    final middayData = middayEntry!['data'] as Map<String, dynamic>;
    final middayInstant =
        (middayData['instant'] as Map<String, dynamic>?)?['details']
            as Map<String, dynamic>?;
    final windSpeedMs = middayInstant?['wind_speed'] as num?;
    final condition = _mapSymbolCode(_symbolCodeFrom(middayData) ?? '');

    var min = temps.first;
    var max = temps.first;
    for (final t in temps) {
      if (t < min) {
        min = t;
      }
      if (t > max) {
        max = t;
      }
    }

    return WeatherForecast(
      forecastFor: date,
      temperatureCelsius: temps.reduce((a, b) => a + b) / temps.length,
      temperatureMinCelsius: min,
      temperatureMaxCelsius: max,
      condition: condition,
      conditionDescription: condition.label,
      windSpeedKmh: windSpeedMs != null ? windSpeedMs.toDouble() * 3.6 : null,
      sourceName: _sourceName,
    );
  }

  /// Symbol code is only present on ~6/12-hourly entries (near-term entries
  /// carry `next_1_hours` instead), so check the coarser blocks first.
  static String? _symbolCodeFrom(Map<String, dynamic> data) {
    for (final key in ['next_6_hours', 'next_12_hours', 'next_1_hours']) {
      final block = data[key] as Map<String, dynamic>?;
      final code =
          (block?['summary'] as Map<String, dynamic>?)?['symbol_code']
              as String?;
      if (code != null) {
        return code;
      }
    }
    return null;
  }

  static WeatherCondition _mapSymbolCode(String symbolCode) {
    final code = symbolCode.toLowerCase();
    if (code.contains('thunder')) {
      return WeatherCondition.thunderstorm;
    }
    if (code.contains('snow') || code.contains('sleet')) {
      return WeatherCondition.snow;
    }
    if (code.contains('fog')) {
      return WeatherCondition.fog;
    }
    if (code.contains('rain')) {
      return WeatherCondition.rain;
    }
    if (code.contains('partlycloudy')) {
      return WeatherCondition.partlyCloudy;
    }
    if (code.contains('cloudy')) {
      return WeatherCondition.cloudy;
    }
    if (code.contains('fair')) {
      return WeatherCondition.partlyCloudy;
    }
    if (code.contains('clearsky')) {
      return WeatherCondition.clear;
    }
    return WeatherCondition.unknown;
  }
}
