import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'weather_condition.dart';
import 'weather_forecast.dart';
import 'weather_service.dart';

/// Open-Meteo — free, keyless, global — used only as the last-resort
/// fallback when neither official met office source ([NwsWeatherService],
/// [MetNorwayWeatherService]) has an answer.
class OpenMeteoWeatherService implements WeatherService {
  OpenMeteoWeatherService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'KumoTravelApp/1.0 (com.cygnus.travelKumo)';
  static const _sourceName = 'Open-Meteo';
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  Future<WeatherForecast?> forecastFor({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'daily':
          'weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max,windspeed_10m_max',
      'timezone': 'auto',
      'forecast_days': '16',
    });
    final response = await _client.get(
      uri,
      headers: const {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) {
      throw Exception('Open-Meteo request failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = body['daily'] as Map<String, dynamic>?;
    if (daily == null) {
      return null;
    }

    final times = (daily['time'] as List<dynamic>).cast<String>();
    final targetDate = _dateFormat.format(date);
    final index = times.indexOf(targetDate);
    if (index == -1) {
      return null;
    }

    final weatherCode = (daily['weathercode'] as List<dynamic>)[index] as int;
    final described = _describeWeatherCode(weatherCode);
    final maxTemp =
        (daily['temperature_2m_max'] as List<dynamic>)[index] as num;
    final minTemp =
        (daily['temperature_2m_min'] as List<dynamic>)[index] as num;
    final precipitation =
        (daily['precipitation_probability_max'] as List<dynamic>?)?[index]
            as num?;
    final windSpeed =
        (daily['windspeed_10m_max'] as List<dynamic>?)?[index] as num?;

    return WeatherForecast(
      forecastFor: date,
      temperatureCelsius: maxTemp.toDouble(),
      temperatureMinCelsius: minTemp.toDouble(),
      temperatureMaxCelsius: maxTemp.toDouble(),
      condition: described.condition,
      conditionDescription: described.description,
      precipitationProbabilityPercent: precipitation?.round(),
      windSpeedKmh: windSpeed?.toDouble(),
      sourceName: _sourceName,
    );
  }

  /// Maps the WMO weather interpretation codes Open-Meteo's `weathercode`
  /// field uses (https://open-meteo.com/en/docs — "WMO Weather interpretation
  /// codes").
  static ({WeatherCondition condition, String description})
  _describeWeatherCode(int code) {
    return switch (code) {
      0 => (condition: WeatherCondition.clear, description: 'Clear sky'),
      1 => (condition: WeatherCondition.clear, description: 'Mainly clear'),
      2 => (
        condition: WeatherCondition.partlyCloudy,
        description: 'Partly cloudy',
      ),
      3 => (condition: WeatherCondition.cloudy, description: 'Overcast'),
      45 || 48 => (condition: WeatherCondition.fog, description: 'Fog'),
      51 ||
      53 ||
      55 => (condition: WeatherCondition.drizzle, description: 'Drizzle'),
      56 || 57 => (
        condition: WeatherCondition.drizzle,
        description: 'Freezing drizzle',
      ),
      61 || 63 || 65 => (condition: WeatherCondition.rain, description: 'Rain'),
      66 ||
      67 => (condition: WeatherCondition.rain, description: 'Freezing rain'),
      71 ||
      73 ||
      75 => (condition: WeatherCondition.snow, description: 'Snow fall'),
      77 => (condition: WeatherCondition.snow, description: 'Snow grains'),
      80 ||
      81 ||
      82 => (condition: WeatherCondition.rain, description: 'Rain showers'),
      85 ||
      86 => (condition: WeatherCondition.snow, description: 'Snow showers'),
      95 => (
        condition: WeatherCondition.thunderstorm,
        description: 'Thunderstorm',
      ),
      96 || 99 => (
        condition: WeatherCondition.thunderstorm,
        description: 'Thunderstorm with hail',
      ),
      _ => (condition: WeatherCondition.unknown, description: 'Unknown'),
    };
  }
}
