import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../data/datasources/discover_remote_datasource.dart';
import '../../data/repositories/discover_repository_impl.dart';
import '../../domain/repositories/discover_repository.dart';
import '../../domain/usecases/clone_itinerary_usecase.dart';
import '../../domain/usecases/fetch_public_itineraries_usecase.dart';

final _discoverDataSourceProvider = Provider<DiscoverRemoteDataSource>(
  (_) => const DiscoverRemoteDataSource(),
);

final discoverRepositoryProvider = Provider<DiscoverRepository>(
  (ref) => DiscoverRepositoryImpl(ref.watch(_discoverDataSourceProvider)),
);

final fetchPublicItinerariesUseCaseProvider =
    Provider<FetchPublicItinerariesUseCase>(
  (ref) => FetchPublicItinerariesUseCase(ref.watch(discoverRepositoryProvider)),
);

final cloneItineraryUseCaseProvider = Provider<CloneItineraryUseCase>(
  (ref) => CloneItineraryUseCase(ref.watch(discoverRepositoryProvider)),
);

// ── State ─────────────────────────────────────────────────────────────────────

sealed class DiscoverState {
  const DiscoverState();
}

class DiscoverInitial extends DiscoverState {
  const DiscoverInitial();
}

class DiscoverLoading extends DiscoverState {
  const DiscoverLoading();
}

class DiscoverLoaded extends DiscoverState {
  const DiscoverLoaded(this.itineraries);
  final List<TravelItinerary> itineraries;
}

class DiscoverError extends DiscoverState {
  const DiscoverError(this.message);
  final String message;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  DiscoverNotifier(this._fetchUseCase) : super(const DiscoverInitial());

  final FetchPublicItinerariesUseCase _fetchUseCase;

  Future<void> search({String? query}) async {
    state = const DiscoverLoading();
    final result = await _fetchUseCase(
      query: query == null || query.trim().isEmpty ? null : query.trim(),
    );
    state = result.fold(
      (f) => DiscoverError(f.message),
      DiscoverLoaded.new,
    );
  }
}

final discoverNotifierProvider =
    StateNotifierProvider<DiscoverNotifier, DiscoverState>(
  (ref) => DiscoverNotifier(
    ref.watch(fetchPublicItinerariesUseCaseProvider),
  ),
);
