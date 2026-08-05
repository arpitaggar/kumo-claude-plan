import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/weather/weather_condition.dart';
import 'package:kumo_claude/core/weather/weather_forecast.dart';
import 'package:kumo_claude/core/weather/weather_providers.dart';
import 'package:kumo_claude/core/weather/weather_service.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/presentation/widgets/segment_card.dart';

/// Never hits the network and never resolves a forecast — the default stub
/// for tests that don't care about the weather chip, so its async provider
/// can't make these tests flaky or network-dependent.
class _NullWeatherService implements WeatherService {
  @override
  Future<WeatherForecast?> forecastFor({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async => null;
}

class _FakeWeatherService implements WeatherService {
  _FakeWeatherService(this.forecast);

  final WeatherForecast forecast;

  @override
  Future<WeatherForecast?> forecastFor({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async => forecast;
}

void main() {
  const tSegment = TripSegment(
    id: 'seg-1',
    itineraryId: 'it-1',
    orderIndex: 0,
    mode: TransportMode.flight,
    origin: Waypoint(name: 'Munich', latitude: 48.1351, longitude: 11.5820),
    destination: Waypoint(
      name: 'Bangkok',
      latitude: 13.7563,
      longitude: 100.5018,
    ),
  );

  Widget buildCard({
    required VoidCallback onTap,
    TripSegment? segment,
    WeatherService? weatherService,
  }) => ProviderScope(
    overrides: [
      weatherServiceProvider.overrideWithValue(
        weatherService ?? _NullWeatherService(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SegmentCard(segment: segment ?? tSegment, onTap: onTap),
      ),
    ),
  );

  testWidgets('shows origin and destination joined by an arrow', (
    tester,
  ) async {
    await tester.pumpWidget(buildCard(onTap: () {}));
    expect(find.text('Munich → Bangkok'), findsOneWidget);
  });

  testWidgets('shows the transport mode label', (tester) async {
    await tester.pumpWidget(buildCard(onTap: () {}));
    expect(find.textContaining('Flight'), findsOneWidget);
  });

  testWidgets('appends a time segment to the label when departureTime is set', (
    tester,
  ) async {
    // Asserting on the exact formatted date/time would be timezone-dependent
    // (the widget formats in local time) — just check the "·" separator that
    // only appears once a departure time is present alongside the mode label.
    final withTime = tSegment.copyWith(
      departureTime: DateTime.utc(2026, 6, 1, 8),
    );
    await tester.pumpWidget(buildCard(onTap: () {}, segment: withTime));
    expect(find.textContaining('Flight ·'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildCard(onTap: () => tapped = true));

    await tester.tap(find.byType(SegmentCard));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('shows no weather chip for a segment with no date', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        onTap: () {},
        weatherService: _FakeWeatherService(
          WeatherForecast(
            forecastFor: DateTime.now(),
            temperatureCelsius: 24,
            condition: WeatherCondition.clear,
            conditionDescription: 'Clear sky',
            sourceName: 'Open-Meteo',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.wb_sunny), findsNothing);
  });

  testWidgets(
    'shows a weather chip with temperature for an eligible upcoming date',
    (tester) async {
      final segment = tSegment.copyWith(
        arrivalTime: DateTime.now().add(const Duration(days: 2)),
      );
      await tester.pumpWidget(
        buildCard(
          onTap: () {},
          segment: segment,
          weatherService: _FakeWeatherService(
            WeatherForecast(
              forecastFor: DateTime.now(),
              temperatureCelsius: 24,
              temperatureMinCelsius: 20,
              temperatureMaxCelsius: 28,
              condition: WeatherCondition.clear,
              conditionDescription: 'Clear sky',
              sourceName: 'Open-Meteo',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
      expect(find.text('20–28°'), findsOneWidget);
    },
  );

  testWidgets('tapping the weather chip shows the source attribution', (
    tester,
  ) async {
    final segment = tSegment.copyWith(
      arrivalTime: DateTime.now().add(const Duration(days: 2)),
    );
    await tester.pumpWidget(
      buildCard(
        onTap: () {},
        segment: segment,
        weatherService: _FakeWeatherService(
          WeatherForecast(
            forecastFor: DateTime.now(),
            temperatureCelsius: 24,
            condition: WeatherCondition.clear,
            conditionDescription: 'Clear sky',
            sourceName: 'Open-Meteo',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.wb_sunny));
    await tester.pump();

    expect(find.text('Forecast: Open-Meteo'), findsOneWidget);
  });
}
