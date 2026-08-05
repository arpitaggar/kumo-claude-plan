import '../utils/logger.dart';
import 'weather_forecast.dart';
import 'weather_service.dart';

/// Tries each of [sources] in order and returns the first non-null result —
/// "prefer the official met office, fall back to the best generic source
/// available". The entire priority order lives in this one list; reordering,
/// disabling, or adding a source is a one-line change at the call site
/// (see weather_providers.dart) with no changes needed here or in any other
/// source's implementation or tests.
class FallbackWeatherService implements WeatherService {
  FallbackWeatherService(this.sources) : assert(sources.isNotEmpty);

  final List<WeatherService> sources;

  @override
  Future<WeatherForecast?> forecastFor({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    for (final source in sources) {
      try {
        final forecast = await source.forecastFor(
          latitude: latitude,
          longitude: longitude,
          date: date,
        );
        if (forecast != null) {
          return forecast;
        }
      } catch (e) {
        AppLogger.warning(
          '${source.runtimeType} failed to provide a forecast, '
          'trying next source: $e',
        );
      }
    }
    return null;
  }
}
