import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/hitchhiker_access_remote_datasource.dart';
import '../../data/datasources/hitchhiker_remote_datasource.dart';
import '../../data/repositories/hitchhiker_access_repository_impl.dart';
import '../../data/repositories/hitchhiker_repository_impl.dart';
import '../../domain/entities/hitchhiker.dart';
import '../../domain/entities/hitchhiker_trip_view.dart';
import '../../domain/repositories/hitchhiker_access_repository.dart';
import '../../domain/repositories/hitchhiker_repository.dart';
import '../../domain/usecases/create_hitchhiker_usecase.dart';
import '../../domain/usecases/get_hitchhiker_trip_view_usecase.dart';
import '../../domain/usecases/list_hitchhikers_usecase.dart';
import '../../domain/usecases/revoke_hitchhiker_usecase.dart';
import '../../domain/usecases/send_hitchhiker_message_usecase.dart';
import '../../domain/usecases/suggest_hitchhiker_item_usecase.dart';

// ── Captain-side (authenticated) ─────────────────────────────────────────────

final hitchhikerRemoteDataSourceProvider = Provider<HitchhikerRemoteDataSource>(
  (_) => const HitchhikerRemoteDataSourceImpl(),
);

final hitchhikerRepositoryProvider = Provider<HitchhikerRepository>(
  (ref) =>
      HitchhikerRepositoryImpl(ref.watch(hitchhikerRemoteDataSourceProvider)),
);

final createHitchhikerUseCaseProvider = Provider<CreateHitchhikerUseCase>(
  (ref) => CreateHitchhikerUseCase(ref.watch(hitchhikerRepositoryProvider)),
);

final revokeHitchhikerUseCaseProvider = Provider<RevokeHitchhikerUseCase>(
  (ref) => RevokeHitchhikerUseCase(ref.watch(hitchhikerRepositoryProvider)),
);

final listHitchhikersUseCaseProvider = Provider<ListHitchhikersUseCase>(
  (ref) => ListHitchhikersUseCase(ref.watch(hitchhikerRepositoryProvider)),
);

/// A trip's current Hitchhiker roster. Invalidate with
/// `ref.invalidate(hitchhikersForTripProvider(itineraryId))` after
/// create/revoke.
final hitchhikersForTripProvider = FutureProvider.autoDispose
    .family<List<Hitchhiker>, String>((ref, itineraryId) async {
      final result = await ref
          .read(listHitchhikersUseCaseProvider)
          .call(itineraryId);
      return result.fold((_) => [], (list) => list);
    });

// ── Hitchhiker-side (token, no session) ─────────────────────────────────────

final hitchhikerAccessRemoteDataSourceProvider =
    Provider<HitchhikerAccessRemoteDataSource>(
      (_) => const HitchhikerAccessRemoteDataSourceImpl(),
    );

final hitchhikerAccessRepositoryProvider = Provider<HitchhikerAccessRepository>(
  (ref) => HitchhikerAccessRepositoryImpl(
    ref.watch(hitchhikerAccessRemoteDataSourceProvider),
  ),
);

final getHitchhikerTripViewUseCaseProvider =
    Provider<GetHitchhikerTripViewUseCase>(
      (ref) => GetHitchhikerTripViewUseCase(
        ref.watch(hitchhikerAccessRepositoryProvider),
      ),
    );

final sendHitchhikerMessageUseCaseProvider =
    Provider<SendHitchhikerMessageUseCase>(
      (ref) => SendHitchhikerMessageUseCase(
        ref.watch(hitchhikerAccessRepositoryProvider),
      ),
    );

final suggestHitchhikerItemUseCaseProvider =
    Provider<SuggestHitchhikerItemUseCase>(
      (ref) => SuggestHitchhikerItemUseCase(
        ref.watch(hitchhikerAccessRepositoryProvider),
      ),
    );

/// The token-authenticated trip bundle (see `HitchhikerTripView`).
/// `.autoDispose` and not cached beyond the widget's lifetime — re-fetched
/// each time the Hitchhiker screen is opened so new messages/suggestions
/// from Captain/Crew are picked up.
final hitchhikerTripViewProvider = FutureProvider.autoDispose
    .family<HitchhikerTripView, String>((ref, token) async {
      final result = await ref
          .read(getHitchhikerTripViewUseCaseProvider)
          .call(token);
      return result.fold(
        (failure) => throw Exception(failure.message),
        (view) => view,
      );
    });
