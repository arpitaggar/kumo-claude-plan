import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/gamification_remote_datasource.dart';
import '../../data/repositories/gamification_repository_impl.dart';
import '../../domain/entities/xp_event.dart';
import '../../domain/entities/xp_summary.dart';
import '../../domain/usecases/fetch_xp_events_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

final gamificationDataSourceProvider = Provider<GamificationRemoteDataSource>(
  (_) => const GamificationRemoteDataSourceImpl(),
);

final gamificationRepositoryProvider = Provider<GamificationRepositoryImpl>(
  (ref) =>
      GamificationRepositoryImpl(ref.watch(gamificationDataSourceProvider)),
);

final fetchXpEventsUseCaseProvider = Provider<FetchXpEventsUseCase>(
  (ref) => FetchXpEventsUseCase(ref.watch(gamificationRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Read providers
// ---------------------------------------------------------------------------

/// The signed-in user's own XP events, newest first. `autoDispose` — this
/// feature has exactly one consumer surface (Profile + Achievements), so
/// re-fetching fresh on each visit is simpler and safer than manually
/// wiring `ref.invalidate` into every one of the 6 award-triggering call
/// sites scattered across the itinerary/social features. No realtime.
final xpEventsProvider = FutureProvider.autoDispose<List<XpEvent>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) {
    return const [];
  }
  final result = await ref
      .watch(fetchXpEventsUseCaseProvider)
      .call(auth.user.id);
  return result.fold((f) => throw Exception(f.message), (events) => events);
});

/// [XpSummary] derived from [xpEventsProvider] — see that provider for the
/// fetch/refresh reasoning.
final xpSummaryProvider = Provider.autoDispose<AsyncValue<XpSummary>>(
  (ref) => ref.watch(xpEventsProvider).whenData(XpSummary.fromEvents),
);
