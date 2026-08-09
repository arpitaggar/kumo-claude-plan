import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/presentation/pages/add_edit_trip_segment_page.dart';

// Only "add" mode (no segmentId) is exercised here — that path never touches
// tripSegmentsStreamProvider in build(), so it needs no provider overrides or
// a live Supabase instance. "Edit" mode reads that stream to prefill the
// form and would need a proper harness (see trip_segment_provider usage
// elsewhere) to test meaningfully.
Widget buildPage({TripSegment? continueFromSegment}) => ProviderScope(
  child: MaterialApp(
    home: AddEditTripSegmentPage(
      itineraryId: 'it-1',
      continueFromSegment: continueFromSegment,
    ),
  ),
);

void main() {
  group('AddEditTripSegmentPage (add mode)', () {
    testWidgets('shows the Add Segment AppBar title', (tester) async {
      await tester.pumpWidget(buildPage());
      // "Add Segment" also labels the submit button further down, so scope
      // this check to the AppBar specifically.
      expect(find.widgetWithText(AppBar, 'Add Segment'), findsOneWidget);
    });

    testWidgets('shows a chip for every transport mode', (tester) async {
      await tester.pumpWidget(buildPage());
      for (final label in [
        'Flight',
        'Train',
        'Bus',
        'Car',
        'Motorcycle',
        'Ferry',
        'Walk',
        'Other',
      ]) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }
    });

    testWidgets('defaults to Flight selected', (tester) async {
      await tester.pumpWidget(buildPage());
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Flight'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('selecting a different mode chip updates the selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());

      await tester.tap(find.widgetWithText(ChoiceChip, 'Motorcycle'));
      await tester.pump();

      final motorcycleChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Motorcycle'),
      );
      final flightChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Flight'),
      );
      expect(motorcycleChip.selected, isTrue);
      expect(flightChip.selected, isFalse);
    });

    testWidgets('shows Origin and Destination fields, both unset', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Select a location'), findsNWidgets(2));
    });

    testWidgets(
      'submitting without an origin/destination shows a validation snackbar',
      (tester) async {
        await tester.pumpWidget(buildPage());

        // The submit button is below the fold of the scrollable form.
        final submitButton = find.widgetWithText(ElevatedButton, 'Add Segment');
        await tester.ensureVisible(submitButton);
        await tester.pumpAndSettle();
        await tester.tap(submitButton);
        // A SnackBar needs its entrance animation to run before its text is
        // findable — a single pump() isn't enough.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Please select both an origin and a destination'),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping the swap button swaps origin and destination', (
      tester,
    ) async {
      const previousLeg = TripSegment(
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
      await tester.pumpWidget(buildPage(continueFromSegment: previousLeg));

      // "Continue trip from here" prefills origin with the previous leg's
      // destination, so this is a real swap, not just moving nulls around.
      expect(find.text('Bangkok'), findsOneWidget);
      expect(find.text('Select a location'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pump();

      final originField = tester.widget<InputDecorator>(
        find.ancestor(
          of: find.text('Bangkok'),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(originField.decoration.labelText, 'Destination');
    });
  });
}
