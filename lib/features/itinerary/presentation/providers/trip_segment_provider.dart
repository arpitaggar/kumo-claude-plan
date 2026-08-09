import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/routing_service.dart';
import '../../../../core/routing/routing_service_provider.dart';
import '../../../../core/utils/logger.dart';
import '../../data/datasources/trip_segment_remote_datasource.dart';
import '../../data/repositories/trip_segment_repository_impl.dart';
import '../../domain/entities/trip_segment.dart';
import '../../domain/usecases/add_trip_segment_usecase.dart';
import '../../domain/usecases/delete_trip_segment_usecase.dart';
import '../../domain/usecases/reorder_trip_segments_usecase.dart';
import '../../domain/usecases/set_trip_segment_visibility_usecase.dart';
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

final reorderTripSegmentsUseCaseProvider = Provider<ReorderTripSegmentsUseCase>(
  (ref) => ReorderTripSegmentsUseCase(ref.watch(tripSegmentRepositoryProvider)),
);

final setTripSegmentVisibilityUseCaseProvider =
    Provider<SetTripSegmentVisibilityUseCase>(
      (ref) => SetTripSegmentVisibilityUseCase(
        ref.watch(tripSegmentRepositoryProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Stream provider — live segment list per itinerary, ordered by orderIndex
// ---------------------------------------------------------------------------

final tripSegmentsStreamProvider =
    StreamProvider.family<List<TripSegment>, String>(
      (ref, itineraryId) => ref
          .watch(tripSegmentRepositoryProvider)
          .watchSegments(itineraryId)
          .map(
            (either) =>
                either.fold((f) => throw Exception(f.message), (list) => list),
          ),
    );

// ---------------------------------------------------------------------------
// Route geometry — composes RoutingService (core/) with the repository, so
// it lives at the presentation/provider layer rather than as a domain
// usecase, matching how `ResolveAiSegments` composes GeocodingService
// (see lib/features/ai_generation/presentation/providers/
// ai_generation_provider.dart): a domain usecase in this codebase's
// convention never reaches into lib/core/ infrastructure directly.
// ---------------------------------------------------------------------------

class FetchTripSegmentRouteGeometry {
  const FetchTripSegmentRouteGeometry(this._ref);

  final Ref _ref;

  /// Fetches [segment]'s real road/footpath geometry via whichever routing
  /// backend matches the active map engine, and caches it on the segment
  /// row. A no-op if the mode isn't routable or no route could be found —
  /// see `isRoutableMode`/`RoutingService`'s null-on-failure contract.
  Future<void> call(TripSegment segment) async {
    if (!isRoutableMode(segment.mode)) {
      return;
    }

    final routingService = _ref.read(routingServiceProvider);
    final geometry = await routingService.route(
      origin: segment.origin,
      destination: segment.destination,
      mode: segment.mode,
    );
    if (geometry == null) {
      return;
    }

    final result = await _ref
        .read(tripSegmentRepositoryProvider)
        .updateRouteGeometry(segment.id, geometry);
    result.fold(
      (failure) => AppLogger.warning(
        'Failed to cache route geometry for segment ${segment.id}: '
        '${failure.message}',
      ),
      (_) {},
    );
  }
}

final fetchTripSegmentRouteGeometryProvider =
    Provider<FetchTripSegmentRouteGeometry>(FetchTripSegmentRouteGeometry.new);

/// Segment ids the Route tab has already fired a backfill fetch for this
/// app session — a plain `Provider`-held mutable set (not widget state,
/// since `_RouteTab` is a stateless `ConsumerWidget` that rebuilds on every
/// segment-list change) so re-rendering the map doesn't re-request the same
/// segment's geometry on every rebuild.
final routeGeometryBackfillRequestedProvider = Provider<Set<String>>(
  (_) => <String>{},
);
