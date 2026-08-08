import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/itinerary_local_datasource.dart';
import '../../data/datasources/itinerary_remote_datasource.dart';
import '../../data/repositories/itinerary_repository_impl.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../../domain/usecases/create_itinerary_usecase.dart';
import '../../domain/usecases/delete_itinerary_usecase.dart';
import '../../domain/usecases/fetch_itineraries_usecase.dart';
import '../../domain/usecases/fetch_itinerary_usecase.dart';
import '../../domain/usecases/update_itinerary_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final itineraryRemoteDataSourceProvider =
    Provider<ItineraryRemoteDataSource>((_) => const ItineraryRemoteDataSourceImpl());

final itineraryLocalDataSourceProvider =
    Provider<ItineraryLocalDataSource>((_) => const ItineraryLocalDataSource());

final itineraryRepositoryProvider = Provider<ItineraryRepositoryImpl>(
  (ref) => ItineraryRepositoryImpl(
    remoteDataSource: ref.watch(itineraryRemoteDataSourceProvider),
    localDataSource: ref.watch(itineraryLocalDataSourceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final fetchItinerariesUseCaseProvider = Provider<FetchItinerariesUseCase>(
  (ref) => FetchItinerariesUseCase(ref.watch(itineraryRepositoryProvider)),
);

final fetchItineraryUseCaseProvider = Provider<FetchItineraryUseCase>(
  (ref) => FetchItineraryUseCase(ref.watch(itineraryRepositoryProvider)),
);

/// Streams live updates for a single itinerary via Supabase Realtime.
final itineraryStreamProvider = StreamProvider.family<TravelItinerary, String>(
  (ref, id) => ref
      .watch(itineraryRepositoryProvider)
      .watchItinerary(id)
      .map((either) => either.fold(
            (failure) => throw Exception(failure.message),
            (itinerary) => itinerary,
          )),
);

final createItineraryUseCaseProvider = Provider<CreateItineraryUseCase>(
  (ref) => CreateItineraryUseCase(ref.watch(itineraryRepositoryProvider)),
);

final updateItineraryUseCaseProvider = Provider<UpdateItineraryUseCase>(
  (ref) => UpdateItineraryUseCase(ref.watch(itineraryRepositoryProvider)),
);

final deleteItineraryUseCaseProvider = Provider<DeleteItineraryUseCase>(
  (ref) => DeleteItineraryUseCase(ref.watch(itineraryRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Itinerary list state
// ---------------------------------------------------------------------------

sealed class ItineraryListState {
  const ItineraryListState();
}

class ItineraryListInitial extends ItineraryListState {
  const ItineraryListInitial();
}

class ItineraryListLoading extends ItineraryListState {
  const ItineraryListLoading();
}

class ItineraryListLoaded extends ItineraryListState {
  const ItineraryListLoaded(this.itineraries);
  final List<TravelItinerary> itineraries;
}

class ItineraryListError extends ItineraryListState {
  const ItineraryListError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// ItineraryListNotifier
// ---------------------------------------------------------------------------

class ItineraryListNotifier extends StateNotifier<ItineraryListState> {
  ItineraryListNotifier({
    required this.fetchUseCase,
    required this.createUseCase,
    required this.updateUseCase,
    required this.deleteUseCase,
  }) : super(const ItineraryListInitial());

  final FetchItinerariesUseCase fetchUseCase;
  final CreateItineraryUseCase createUseCase;
  final UpdateItineraryUseCase updateUseCase;
  final DeleteItineraryUseCase deleteUseCase;

  Future<void> loadItineraries(String userId) async {
    state = const ItineraryListLoading();
    try {
      final result = await fetchUseCase(userId);
      result.fold(
        (failure) => state = ItineraryListError(failure.message),
        (list) => state = ItineraryListLoaded(list),
      );
    } catch (e) {
      state = ItineraryListError(e.toString());
    }
  }

  /// Refreshes the list without showing the loading state.
  Future<void> softRefresh(String userId) async {
    try {
      final result = await fetchUseCase(userId);
      result.fold(
        (_) {}, // silent fail — keep showing whatever is currently displayed
        (list) => state = ItineraryListLoaded(list),
      );
    } catch (_) {}
  }

  /// Returns the created trip on success (so a caller can attach further
  /// per-trip data, e.g. cost-tracking field values, using its id) or null
  /// on failure.
  Future<TravelItinerary?> createItinerary({
    required String title,
    required String ownerId,
    required String ownerName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalBudget,
    required String currencyCode,
    String? description,
    List<ItineraryItem>? items,
    String themeKey = 'classic',
    String? orgId,
  }) async {
    final result = await createUseCase(
      title: title,
      ownerId: ownerId,
      ownerName: ownerName,
      startDate: startDate,
      endDate: endDate,
      totalBudget: totalBudget,
      currencyCode: currencyCode,
      description: description,
      items: items,
      themeKey: themeKey,
      orgId: orgId,
    );
    return result.fold(
      (failure) {
        state = ItineraryListError(failure.message);
        return null;
      },
      (newItinerary) {
        final existing = state is ItineraryListLoaded
            ? (state as ItineraryListLoaded).itineraries
            : <TravelItinerary>[];
        state = ItineraryListLoaded([newItinerary, ...existing]);
        return newItinerary;
      },
    );
  }

  Future<void> deleteItinerary(String id) async {
    final result = await deleteUseCase(id);
    result.fold(
      (failure) => state = ItineraryListError(failure.message),
      (_) {
        if (state is ItineraryListLoaded) {
          final current = (state as ItineraryListLoaded).itineraries;
          state = ItineraryListLoaded(
            current.where((i) => i.id != id).toList(),
          );
        }
      },
    );
  }
}

final itineraryListProvider =
    StateNotifierProvider<ItineraryListNotifier, ItineraryListState>(
      (ref) => ItineraryListNotifier(
        fetchUseCase: ref.watch(fetchItinerariesUseCaseProvider),
        createUseCase: ref.watch(createItineraryUseCaseProvider),
        updateUseCase: ref.watch(updateItineraryUseCaseProvider),
        deleteUseCase: ref.watch(deleteItineraryUseCaseProvider),
      ),
    );
