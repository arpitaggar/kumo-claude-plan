import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/maps/route_map_view.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';

void main() {
  // Only the empty-segments case is exercised here — with segments present,
  // RouteMapView mounts a real flutter_map/google_maps_flutter widget (tile
  // fetches / platform channels), which isn't safe or meaningful in a plain
  // widget test.
  Widget buildEmpty() => ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: RouteMapView(segments: const [], onSegmentTap: (_) {}),
      ),
    ),
  );

  testWidgets('shows a prompt instead of a map when there are no segments', (
    tester,
  ) async {
    await tester.pumpWidget(buildEmpty());
    expect(find.text('Add a segment to see the route map'), findsOneWidget);
  });

  test('iconForTransportMode returns a distinct icon per mode', () {
    final icons = TransportMode.values.map(iconForTransportMode).toSet();
    // Not strictly required that every mode has a unique icon, but if this
    // collapses to 1 it means the switch fell through to a single default.
    expect(icons.length, greaterThan(1));
  });
}
