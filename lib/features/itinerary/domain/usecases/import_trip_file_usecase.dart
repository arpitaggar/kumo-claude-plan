import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/travel_itinerary.dart';
import '../entities/trip_file.dart';
import 'add_trip_segment_usecase.dart';
import 'create_itinerary_usecase.dart';

/// Creates a private, independent itinerary for the current user from an
/// imported [TripFile] — the file-based counterpart to `ForkPostUseCase`
/// ("use this itinerary" from the social feed). Same scope, same result: a
/// brand-new trip owned solely by the new owner, with a fresh id, zero
/// budget, and no members but the importer.
class ImportTripFileUseCase {
  const ImportTripFileUseCase(this._createItinerary, this._addSegment);

  final CreateItineraryUseCase _createItinerary;
  final AddTripSegmentUseCase _addSegment;

  Future<Either<Failure, TravelItinerary>> call({
    required TripFile file,
    required String newOwnerId,
    required String newOwnerName,
  }) async {
    final createResult = await _createItinerary(
      title: file.title,
      ownerId: newOwnerId,
      ownerName: newOwnerName,
      startDate: file.startDate,
      endDate: file.endDate,
      totalBudget: 0,
      currencyCode: file.currencyCode,
      description: file.description,
      items: file.items,
      themeKey: file.themeKey,
    );
    if (createResult.isLeft()) {
      return createResult;
    }
    final itinerary = createResult.getOrElse(
      () => throw StateError('unreachable: checked isLeft above'),
    );

    // Segments are added one by one via the existing repository path
    // (rather than the ItineraryModel's own array) so ordering/validation
    // stays identical to a user adding them by hand. A single segment
    // failing to insert doesn't roll back the trip itself — it's already a
    // useful, mostly-complete import either way.
    for (final segment in file.segments) {
      await _addSegment(
        itineraryId: itinerary.id,
        orderIndex: segment.orderIndex,
        mode: segment.mode,
        origin: segment.origin,
        destination: segment.destination,
        departureTime: segment.departureTime,
        arrivalTime: segment.arrivalTime,
        notes: segment.notes,
      );
    }

    return Right(itinerary);
  }
}
