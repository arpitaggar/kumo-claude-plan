import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/geocoding/geocoding_providers.dart';
import '../../../itinerary/domain/entities/waypoint.dart';
import '../../../itinerary/presentation/providers/trip_segment_provider.dart';
import '../../data/datasources/ai_generation_datasource.dart';
import '../../data/repositories/ai_generation_repository_impl.dart';
import '../../domain/entities/ai_generated_segment.dart';
import '../../domain/entities/ai_generation_request.dart';
import '../../domain/entities/ai_generation_result.dart';
import '../../domain/usecases/generate_itinerary_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

final aiGenerationDataSourceProvider = Provider<AiGenerationDataSource>(
  (_) => const AiGenerationDataSourceImpl(),
);

final aiGenerationRepositoryProvider =
    Provider<AiGenerationRepositoryImpl>(
  (ref) => AiGenerationRepositoryImpl(
    dataSource: ref.watch(aiGenerationDataSourceProvider),
  ),
);

final generateItineraryUseCaseProvider = Provider<GenerateItineraryUseCase>(
  (ref) => GenerateItineraryUseCase(
    ref.watch(aiGenerationRepositoryProvider),
  ),
);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

sealed class AiGenerationState {
  const AiGenerationState();
}

class AiGenerationIdle extends AiGenerationState {
  const AiGenerationIdle();
}

class AiGenerationLoading extends AiGenerationState {
  const AiGenerationLoading();
}

class AiGenerationSuccess extends AiGenerationState {
  const AiGenerationSuccess(this.result);
  final AiGenerationResult result;
}

class AiGenerationError extends AiGenerationState {
  const AiGenerationError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AiGenerationNotifier extends StateNotifier<AiGenerationState> {
  AiGenerationNotifier(this._useCase) : super(const AiGenerationIdle());

  final GenerateItineraryUseCase _useCase;

  Future<void> generate(AiGenerationRequest request) async {
    state = const AiGenerationLoading();
    final result = await _useCase(request);
    state = result.fold(
      (f) => AiGenerationError(f.message),
      AiGenerationSuccess.new,
    );
  }

  void reset() => state = const AiGenerationIdle();
}

final aiGenerationProvider =
    StateNotifierProvider.autoDispose<AiGenerationNotifier, AiGenerationState>(
  (ref) => AiGenerationNotifier(ref.watch(generateItineraryUseCaseProvider)),
);

// ---------------------------------------------------------------------------
// Resolving AI-generated segments (city names) into real TripSegments
// (geocoded lat/lng) and inserting them once an itinerary exists to attach
// them to. Lives here rather than as a domain usecase because it composes
// two other features' infrastructure (core/geocoding + itinerary's trip
// segment repository) — matches how this app does cross-feature composition
// at the presentation/provider layer elsewhere (e.g. itinerary_detail_page
// wiring in chat/expense/packing/ratings providers directly).
// ---------------------------------------------------------------------------

final resolveAiSegmentsProvider = Provider<ResolveAiSegments>(ResolveAiSegments.new);

class ResolveAiSegments {
  const ResolveAiSegments(this._ref);

  final Ref _ref;

  /// Geocodes each [segments] leg's origin/destination city name (taking the
  /// first search hit) and inserts the resolved segment in order. A leg whose
  /// origin or destination can't be geocoded is skipped rather than failing
  /// the whole batch — the rest of the trip's segments still get created.
  Future<void> call(String itineraryId, List<AiGeneratedSegment> segments) async {
    final geocoder = _ref.read(geocodingServiceProvider);
    final addSegment = _ref.read(addTripSegmentUseCaseProvider);

    var orderIndex = 0;
    for (final segment in segments) {
      final originHits = await geocoder.search(segment.originName);
      final destinationHits = await geocoder.search(segment.destinationName);
      if (originHits.isEmpty || destinationHits.isEmpty) {
        continue;
      }

      await addSegment(
        itineraryId: itineraryId,
        orderIndex: orderIndex,
        mode: segment.mode,
        origin: Waypoint(
          name: originHits.first.name,
          latitude: originHits.first.latitude,
          longitude: originHits.first.longitude,
        ),
        destination: Waypoint(
          name: destinationHits.first.name,
          latitude: destinationHits.first.latitude,
          longitude: destinationHits.first.longitude,
        ),
        departureTime: segment.departureTime,
        arrivalTime: segment.arrivalTime,
      );
      orderIndex++;
    }
  }
}
