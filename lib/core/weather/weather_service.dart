import '../geocoding/nominatim_geocoding_service.dart'
    show NominatimGeocodingService;
import 'fallback_weather_service.dart' show FallbackWeatherService;
import 'weather_forecast.dart';

/// A single weather data source. Implementations are self-contained and
/// interchangeable — see [FallbackWeatherService] (fallback_weather_service.dart)
/// for how an ordered list of these is turned into "prefer the official met
/// office, fall back to the best generic source available".
abstract class WeatherService {
  /// Forecast for the given [date] (a calendar date — time-of-day is
  /// ignored) at [latitude]/[longitude].
  ///
  /// Returns `null` when this source simply doesn't have an answer — the
  /// location is outside its coverage area, or [date] is outside its
  /// forecast horizon. That is an expected, ordinary outcome (mirrors
  /// [NominatimGeocodingService] returning `[]` for no results), not an
  /// error condition. Only genuine transport/parse failures throw.
  Future<WeatherForecast?> forecastFor({
    required double latitude,
    required double longitude,
    required DateTime date,
  });
}
