import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/presentation/widgets/segment_card.dart';

void main() {
  const tSegment = TripSegment(
    id: 'seg-1',
    itineraryId: 'it-1',
    orderIndex: 0,
    mode: TransportMode.flight,
    origin: Waypoint(name: 'Munich', latitude: 48.1351, longitude: 11.5820),
    destination:
        Waypoint(name: 'Bangkok', latitude: 13.7563, longitude: 100.5018),
  );

  Widget buildCard({required VoidCallback onTap, TripSegment? segment}) =>
      MaterialApp(
        home: Scaffold(
          body: SegmentCard(segment: segment ?? tSegment, onTap: onTap),
        ),
      );

  testWidgets('shows origin and destination joined by an arrow',
      (tester) async {
    await tester.pumpWidget(buildCard(onTap: () {}));
    expect(find.text('Munich → Bangkok'), findsOneWidget);
  });

  testWidgets('shows the transport mode label', (tester) async {
    await tester.pumpWidget(buildCard(onTap: () {}));
    expect(find.textContaining('Flight'), findsOneWidget);
  });

  testWidgets('appends a time segment to the label when departureTime is set',
      (tester) async {
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
}
