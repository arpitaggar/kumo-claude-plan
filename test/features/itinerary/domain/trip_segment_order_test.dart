import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/domain/trip_segment_order.dart';

void main() {
  const origin = Waypoint(name: 'A', latitude: 0, longitude: 0);
  const destination = Waypoint(name: 'B', latitude: 1, longitude: 1);

  TripSegment segment({
    required String id,
    required int orderIndex,
    DateTime? departureTime,
    DateTime? arrivalTime,
  }) => TripSegment(
    id: id,
    itineraryId: 'it-1',
    orderIndex: orderIndex,
    mode: TransportMode.flight,
    origin: origin,
    destination: destination,
    departureTime: departureTime,
    arrivalTime: arrivalTime,
  );

  test('sorts dated segments chronologically by departureTime', () {
    final late = segment(
      id: 'late',
      orderIndex: 0,
      departureTime: DateTime.utc(2026, 6, 5),
    );
    final early = segment(
      id: 'early',
      orderIndex: 1,
      departureTime: DateTime.utc(2026, 6, 1),
    );

    final sorted = [late, early]..sort(compareSegmentsChronologically);

    expect(sorted.map((s) => s.id), ['early', 'late']);
  });

  test('ignores orderIndex when both segments are dated', () {
    // orderIndex says [b, a] but departureTime says [a, b] — date wins.
    final a = segment(
      id: 'a',
      orderIndex: 1,
      departureTime: DateTime.utc(2026, 6, 1),
    );
    final b = segment(
      id: 'b',
      orderIndex: 0,
      departureTime: DateTime.utc(2026, 6, 2),
    );

    final sorted = [b, a]..sort(compareSegmentsChronologically);

    expect(sorted.map((s) => s.id), ['a', 'b']);
  });

  test('falls back to arrivalTime when departureTime is unset', () {
    final late = segment(
      id: 'late',
      orderIndex: 0,
      arrivalTime: DateTime.utc(2026, 6, 5),
    );
    final early = segment(
      id: 'early',
      orderIndex: 1,
      arrivalTime: DateTime.utc(2026, 6, 1),
    );

    final sorted = [late, early]..sort(compareSegmentsChronologically);

    expect(sorted.map((s) => s.id), ['early', 'late']);
  });

  test('sorts undated segments after every dated segment', () {
    final dated = segment(
      id: 'dated',
      orderIndex: 5,
      departureTime: DateTime.utc(2026, 12, 31),
    );
    final undated = segment(id: 'undated', orderIndex: 0);

    final sorted = [undated, dated]..sort(compareSegmentsChronologically);

    expect(sorted.map((s) => s.id), ['dated', 'undated']);
  });

  test('sorts undated segments among themselves by orderIndex', () {
    final second = segment(id: 'second', orderIndex: 1);
    final first = segment(id: 'first', orderIndex: 0);

    final sorted = [second, first]..sort(compareSegmentsChronologically);

    expect(sorted.map((s) => s.id), ['first', 'second']);
  });

  test('deleting a segment never changes the relative order of the rest', () {
    final segments = [
      segment(id: 'x', orderIndex: 0, departureTime: DateTime.utc(2026, 1, 1)),
      segment(id: 'y', orderIndex: 1, departureTime: DateTime.utc(2026, 2, 1)),
      segment(id: 'z', orderIndex: 2, departureTime: DateTime.utc(2026, 3, 1)),
    ];
    final before = [...segments]..sort(compareSegmentsChronologically);

    // Deleting 'y' without renumbering the survivors' orderIndex — the
    // real deletion flow no longer calls ReorderTripSegmentsUseCase.
    final after = [segments[0], segments[2]]
      ..sort(compareSegmentsChronologically);

    expect(
      after.map((s) => s.id),
      before.where((s) => s.id != 'y').map((s) => s.id),
    );
  });
}
