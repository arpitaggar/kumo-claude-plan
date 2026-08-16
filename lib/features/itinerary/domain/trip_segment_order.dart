import 'entities/trip_segment.dart';

/// Orders legs by when they actually happen rather than by
/// [TripSegment.orderIndex] — deleting a segment must never shuffle the rest of the
/// route, and `orderIndex` is otherwise just an insertion-order bookkeeping
/// field (see `ReorderTripSegmentsUseCase`'s doc comment). Segments with a
/// date sort chronologically by `departureTime` (falling back to
/// `arrivalTime`); undated segments (still being roughed out, before times
/// are pinned down) sort after every dated segment, in `orderIndex` order
/// so "Continue trip from here" still keeps them in the sequence the
/// traveller built them in.
///
/// Pulled into its own file (mirroring `route_curve.dart`) so this ordering
/// rule has a real unit test rather than only being exercisable through a
/// mounted `itinerary_detail_page.dart` Route tab.
int compareSegmentsChronologically(TripSegment a, TripSegment b) {
  final aDate = a.departureTime ?? a.arrivalTime;
  final bDate = b.departureTime ?? b.arrivalTime;
  if (aDate == null && bDate == null) {
    return a.orderIndex.compareTo(b.orderIndex);
  }
  if (aDate == null) {
    return 1;
  }
  if (bDate == null) {
    return -1;
  }
  final cmp = aDate.compareTo(bDate);
  return cmp != 0 ? cmp : a.orderIndex.compareTo(b.orderIndex);
}
