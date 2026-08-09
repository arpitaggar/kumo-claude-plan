import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/maps/route_map_view.dart';
import '../../../../core/weather/weather_condition.dart';
import '../../../../core/weather/weather_forecast.dart';
import '../../../../core/weather/weather_providers.dart';
import '../../domain/entities/trip_segment.dart';

/// How far ahead a forecast can realistically be shown — the furthest of
/// the three [WeatherService] sources (Open-Meteo) only forecasts 16 days
/// out, so there's no point watching the provider (or showing a loading
/// spinner) for a segment further out than that.
const _forecastHorizon = Duration(days: 16);

class SegmentCard extends ConsumerWidget {
  const SegmentCard({
    required this.segment,
    required this.onTap,
    this.onToggleVisibility,
    super.key,
  });

  final TripSegment segment;
  final VoidCallback onTap;

  /// Toggles whether this leg is drawn on the Route tab's map — omit to
  /// hide the toggle control entirely (e.g. in a read-only context).
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final departure = segment.departureTime;
    final isVisible = segment.isVisible;

    return Opacity(
      opacity: isVisible ? 1 : 0.55,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: Icon(iconForTransportMode(segment.mode)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${segment.origin.name} → ${segment.destination.name}',
                        style: textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          segment.mode.label,
                          if (departure != null)
                            DateFormat(
                              'MMM d, h:mm a',
                            ).format(departure.toLocal()),
                        ].join(' · '),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _WeatherChip(segment: segment),
                if (onToggleVisibility != null)
                  IconButton(
                    onPressed: onToggleVisibility,
                    tooltip: isVisible ? 'Hide from map' : 'Show on map',
                    icon: Icon(
                      isVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small "forecast for the destination" chip. Renders nothing while
/// loading, on error, or when no source has data — weather is a decorative
/// addition to the segment row and must never block it or show clutter.
class _WeatherChip extends ConsumerWidget {
  const _WeatherChip({required this.segment});

  final TripSegment segment;

  DateTime? get _forecastDate {
    final raw = (segment.arrivalTime ?? segment.departureTime)?.toLocal();
    if (raw == null) {
      return null;
    }
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(raw.year, raw.month, raw.day);
    if (dateOnly.isBefore(todayOnly) ||
        dateOnly.difference(todayOnly) > _forecastHorizon) {
      return null;
    }
    return dateOnly;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = _forecastDate;
    if (date == null) {
      return const SizedBox.shrink();
    }

    final request = WeatherRequest(
      latitude: segment.destination.latitude,
      longitude: segment.destination.longitude,
      date: date,
    );
    final forecastAsync = ref.watch(segmentWeatherProvider(request));

    return forecastAsync.when(
      data: (forecast) => forecast == null
          ? const SizedBox.shrink()
          : _WeatherChipContent(forecast: forecast),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _WeatherChipContent extends StatelessWidget {
  const _WeatherChipContent({required this.forecast});

  final WeatherForecast forecast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Forecast: ${forecast.sourceName}')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconForCondition(forecast.condition),
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              Text(
                _formatTemperature(forecast),
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTemperature(WeatherForecast forecast) {
  final min = forecast.temperatureMinCelsius;
  final max = forecast.temperatureMaxCelsius;
  if (min != null && max != null && min.round() != max.round()) {
    return '${min.round()}–${max.round()}°';
  }
  return '${forecast.temperatureCelsius.round()}°';
}

IconData _iconForCondition(WeatherCondition condition) {
  switch (condition) {
    case WeatherCondition.clear:
      return Icons.wb_sunny;
    case WeatherCondition.partlyCloudy:
      return Icons.wb_cloudy;
    case WeatherCondition.cloudy:
      return Icons.cloud;
    case WeatherCondition.fog:
      return Icons.blur_on;
    case WeatherCondition.drizzle:
      return Icons.grain;
    case WeatherCondition.rain:
      return Icons.umbrella;
    case WeatherCondition.snow:
      return Icons.ac_unit;
    case WeatherCondition.thunderstorm:
      return Icons.thunderstorm;
    case WeatherCondition.unknown:
      return Icons.help_outline;
  }
}
