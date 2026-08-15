import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../work_mode/presentation/providers/work_mode_provider.dart';
import '../../data/datasources/itinerary_local_datasource.dart';
import '../../data/datasources/itinerary_remote_datasource.dart';
import '../../data/repositories/itinerary_repository_impl.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../../domain/repositories/itinerary_repository.dart';
import '../../domain/usecases/create_itinerary_usecase.dart';
import '../../domain/usecases/delete_itinerary_usecase.dart';
import '../../domain/usecases/fetch_itineraries_usecase.dart';
import '../../domain/usecases/fetch_itinerary_usecase.dart';
import '../../domain/usecases/import_trip_file_usecase.dart';
import '../../domain/usecases/update_itinerary_usecase.dart';
import 'trip_segment_provider.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final itineraryRemoteDataSourceProvider = Provider<ItineraryRemoteDataSource>(
  (_) => const ItineraryRemoteDataSourceImpl(),
);

final itineraryLocalDataSourceProvider = Provider<ItineraryLocalDataSource>(
  (_) => const ItineraryLocalDataSource(),
);

final itineraryRepositoryProvider = Provider<ItineraryRepository>(
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
      .map(
        (either) => either.fold(
          (failure) => throw Exception(failure.message),
          (itinerary) => itinerary,
        ),
      ),
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

final importTripFileUseCaseProvider = Provider<ImportTripFileUseCase>(
  (ref) => ImportTripFileUseCase(
    ref.watch(createItineraryUseCaseProvider),
    ref.watch(addTripSegmentUseCaseProvider),
  ),
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
    List<String> accommodationSources = const [],
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
      accommodationSources: accommodationSources,
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

  /// Updates a trip and patches it into the cached list in place, so
  /// Home/Trips cards reflect the change immediately. This list is a
  /// plain fetched snapshot, not a live stream — unlike
  /// `itineraryStreamProvider` (which the detail page itself watches and
  /// so already updates correctly), nothing keeps it in sync with an edit
  /// made elsewhere unless the caller goes through this method instead of
  /// calling `updateItineraryUseCaseProvider` directly. Returns the same
  /// `Either` the use case does (rather than swallowing the failure) so
  /// every existing call site's own `result.fold((f) => ..., ...)` error
  /// handling keeps working unchanged — only where `result` comes from
  /// needs to change.
  Future<Either<Failure, TravelItinerary>> updateItinerary(
    TravelItinerary itinerary,
  ) async {
    final result = await updateUseCase(itinerary);
    result.fold((_) {}, (saved) {
      if (state is ItineraryListLoaded) {
        final current = (state as ItineraryListLoaded).itineraries;
        state = ItineraryListLoaded([
          for (final i in current)
            if (i.id == saved.id) saved else i,
        ]);
      }
    });
    return result;
  }

  Future<void> deleteItinerary(String id) async {
    final result = await deleteUseCase(id);
    result.fold((failure) => state = ItineraryListError(failure.message), (_) {
      if (state is ItineraryListLoaded) {
        final current = (state as ItineraryListLoaded).itineraries;
        state = ItineraryListLoaded(current.where((i) => i.id != id).toList());
      }
    });
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

/// The trips relevant to the current mode: personal (untagged) trips in
/// Private Mode, or the signed-in user's own trips (owned or member of) at
/// the current work org in Work Mode.
///
/// The ownerId/members recheck is currently redundant against what
/// `fetchItineraries()` returns — `org_admin_trip_visibility_select`, the
/// RLS policy that used to grant org admins row-visibility into teammates'
/// org-tagged trips, was removed in stage32 (SEC-3: it leaked full row data,
/// not just the row's existence) and never replaced with an equivalent
/// grant, so RLS alone already scopes every fetch to owned/member trips. The
/// recheck is kept anyway as defense-in-depth and to lock in the confirmed
/// Work Mode scope decision (your own trips only, never a teammate-oversight
/// view) against a future RLS change silently reintroducing broader
/// visibility.
final visibleItinerariesProvider = Provider<List<TravelItinerary>>((ref) {
  final listState = ref.watch(itineraryListProvider);
  final all = listState is ItineraryListLoaded
      ? listState.itineraries
      : const <TravelItinerary>[];

  if (!ref.watch(isWorkModeActiveProvider)) {
    return all.where((t) => t.orgId == null).toList();
  }

  final orgId = ref.watch(currentWorkOrgProvider)?.id;
  final auth = ref.watch(authNotifierProvider);
  final userId = auth is AuthAuthenticated ? auth.user.id : null;
  return all
      .where(
        (t) =>
            t.orgId == orgId &&
            (t.ownerId == userId || t.members.any((m) => m.userId == userId)),
      )
      .toList();
});
