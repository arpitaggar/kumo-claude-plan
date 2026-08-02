import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/trip_segment_remote_datasource.dart';
import '../../data/repositories/trip_segment_repository_impl.dart';
import '../../domain/entities/trip_segment.dart';
import '../../domain/usecases/add_trip_segment_usecase.dart';
import '../../domain/usecases/delete_trip_segment_usecase.dart';
import '../../domain/usecases/reorder_trip_segments_usecase.dart';
import '../../domain/usecases/update_trip_segment_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

final tripSegmentDataSourceProvider = Provider<TripSegmentRemoteDataSource>(
  (_) => const TripSegmentRemoteDataSourceImpl(),
);

final tripSegmentRepositoryProvider = Provider<TripSegmentRepositoryImpl>(
  (ref) => TripSegmentRepositoryImpl(
    dataSource: ref.watch(tripSegmentDataSourceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final addTripSegmentUseCaseProvider = Provider<AddTripSegmentUseCase>(
  (ref) => AddTripSegmentUseCase(ref.watch(tripSegmentRepositoryProvider)),
);

final updateTripSegmentUseCaseProvider = Provider<UpdateTripSegmentUseCase>(
  (ref) => UpdateTripSegmentUseCase(ref.watch(tripSegmentRepositoryProvider)),
);

final deleteTripSegmentUseCaseProvider = Provider<DeleteTripSegmentUseCase>(
  (ref) => DeleteTripSegmentUseCase(ref.watch(tripSegmentRepositoryProvider)),
);

final reorderTripSegmentsUseCaseProvider =
    Provider<ReorderTripSegmentsUseCase>(
  (ref) => ReorderTripSegmentsUseCase(ref.watch(tripSegmentRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Stream provider — live segment list per itinerary, ordered by orderIndex
// ---------------------------------------------------------------------------

final tripSegmentsStreamProvider =
    StreamProvider.family<List<TripSegment>, String>((ref, itineraryId) => ref
        .watch(tripSegmentRepositoryProvider)
        .watchSegments(itineraryId)
        .map((either) => either.fold(
              (f) => throw Exception(f.message),
              (list) => list,
            )));
