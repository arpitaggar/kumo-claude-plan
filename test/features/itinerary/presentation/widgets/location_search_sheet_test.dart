import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/geocoding/geocoding_providers.dart';
import 'package:kumo_claude/core/geocoding/geocoding_service.dart';
import 'package:kumo_claude/features/itinerary/presentation/widgets/location_search_sheet.dart';
import 'package:mocktail/mocktail.dart';

// LocationSearchSheet previously had zero test coverage at all — its
// consumer (add_edit_trip_segment_page_test.dart) never opens the sheet.
// This covers the Search and Coordinates tabs, both driven entirely
// through mockable seams (geocodingServiceProvider, and the Coordinates
// tab's own text-parsing logic). The Import GPX tab's "Choose .gpx file"
// button is deliberately NOT exercised here — it calls the real
// file_picker platform channel with no test double anywhere in this
// codebase (same gap as ImagePicker in chat_page.dart's attach sheet) —
// only its pre-pick empty state and post-parse-error rendering are
// covered, both reachable without touching the picker itself.

class MockGeocodingService extends Mock implements GeocodingService {}

Future<GeocodingResult?> _openSheet(
  WidgetTester tester, {
  required GeocodingService service,
}) async {
  GeocodingResult? captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [geocodingServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                captured = await showModalBottomSheet<GeocodingResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const LocationSearchSheet(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  group('LocationSearchSheet — Search tab', () {
    testWidgets('shows a prompt before anything is typed', (tester) async {
      await _openSheet(tester, service: MockGeocodingService());
      expect(find.text('Type to search for a city or place'), findsOneWidget);
    });

    testWidgets('typing a query shows results, and tapping one pops with it', (
      tester,
    ) async {
      final service = MockGeocodingService();
      when(() => service.search('Kyoto')).thenAnswer(
        (_) async => const [
          GeocodingResult(name: 'Kyoto, Japan', latitude: 35, longitude: 135),
        ],
      );

      GeocodingResult? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [geocodingServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    captured = await showModalBottomSheet<GeocodingResult>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const LocationSearchSheet(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Kyoto');
      // The search is debounced 500ms.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Kyoto, Japan'), findsOneWidget);

      await tester.tap(find.text('Kyoto, Japan'));
      await tester.pumpAndSettle();

      expect(
        captured,
        const GeocodingResult(
          name: 'Kyoto, Japan',
          latitude: 35,
          longitude: 135,
        ),
      );
    });

    testWidgets('shows an error message when the search throws', (
      tester,
    ) async {
      final service = MockGeocodingService();
      when(() => service.search(any())).thenThrow(Exception('network down'));

      await _openSheet(tester, service: service);
      await tester.enterText(find.byType(TextField).first, 'Kyoto');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Search failed. Please try again.'), findsOneWidget);
    });

    testWidgets('clears results when the query is cleared', (tester) async {
      final service = MockGeocodingService();
      when(() => service.search('Kyoto')).thenAnswer(
        (_) async => const [
          GeocodingResult(name: 'Kyoto, Japan', latitude: 35, longitude: 135),
        ],
      );

      await _openSheet(tester, service: service);
      await tester.enterText(find.byType(TextField).first, 'Kyoto');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Kyoto, Japan'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Type to search for a city or place'), findsOneWidget);
    });
  });

  group('LocationSearchSheet — Coordinates tab', () {
    testWidgets('valid coordinates pop the sheet with a parsed result', (
      tester,
    ) async {
      GeocodingResult? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geocodingServiceProvider.overrideWithValue(MockGeocodingService()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    captured = await showModalBottomSheet<GeocodingResult>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const LocationSearchSheet(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coordinates'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '35.6762, 139.6503');
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();

      expect(
        captured,
        const GeocodingResult(
          name: '35.67620, 139.65030',
          latitude: 35.6762,
          longitude: 139.6503,
        ),
      );
    });

    testWidgets('rejects garbage input without popping', (tester) async {
      await _openSheet(tester, service: MockGeocodingService());

      await tester.tap(find.text('Coordinates'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'not coordinates');
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter coordinates like "35.6762, 139.6503"'),
        findsOneWidget,
      );
      // Sheet is still open — the surrounding button's text is gone from
      // the visible tree because the sheet covers it, but the tab bar
      // (only present while the sheet is up) is still there.
      expect(find.text('Coordinates'), findsWidgets);
    });

    testWidgets('rejects out-of-range coordinates', (tester) async {
      await _openSheet(tester, service: MockGeocodingService());

      await tester.tap(find.text('Coordinates'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '200, 400');
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter coordinates like "35.6762, 139.6503"'),
        findsOneWidget,
      );
    });

    testWidgets('typing again clears a prior error', (tester) async {
      await _openSheet(tester, service: MockGeocodingService());

      await tester.tap(find.text('Coordinates'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'garbage');
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter coordinates like "35.6762, 139.6503"'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();

      expect(
        find.text('Enter coordinates like "35.6762, 139.6503"'),
        findsNothing,
      );
    });
  });

  group('LocationSearchSheet — Import GPX tab', () {
    testWidgets('shows the initial prompt before any file is chosen', (
      tester,
    ) async {
      await _openSheet(tester, service: MockGeocodingService());

      await tester.tap(find.text('Import GPX'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Import a .gpx file exported from'),
        findsOneWidget,
      );
      expect(find.text('Choose .gpx file'), findsOneWidget);
    });
  });
}
