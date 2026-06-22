import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../data/datasources/ai_generation_datasource.dart';
import '../../data/repositories/ai_generation_repository_impl.dart';
import '../../domain/entities/ai_generation_request.dart';
import '../../domain/usecases/generate_itinerary_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

final aiGenerationDataSourceProvider = Provider<AiGenerationDataSource>(
  (_) => AiGenerationDataSourceImpl(),
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
  const AiGenerationSuccess(this.items);
  final List<ItineraryItem> items;
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
