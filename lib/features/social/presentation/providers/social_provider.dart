import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/social_remote_datasource.dart';
import '../../data/repositories/social_repository_impl.dart';
import '../../domain/entities/follow_stats.dart';
import '../../domain/entities/itinerary_post.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/usecases/fetch_explore_posts_usecase.dart';
import '../../domain/usecases/fetch_follow_stats_usecase.dart';
import '../../domain/usecases/fetch_following_feed_usecase.dart';
import '../../domain/usecases/fetch_posts_by_author_usecase.dart';
import '../../domain/usecases/fork_post_usecase.dart';
import '../../domain/usecases/publish_itinerary_usecase.dart';
import '../../domain/usecases/toggle_follow_usecase.dart';
import '../../domain/usecases/toggle_like_usecase.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final socialRemoteDataSourceProvider = Provider<SocialRemoteDataSource>(
  (_) => const SocialRemoteDataSourceImpl(),
);

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepositoryImpl(ref.watch(socialRemoteDataSourceProvider)),
);

// ── Use-case providers ───────────────────────────────────────────────────────

final publishItineraryUseCaseProvider = Provider<PublishItineraryUseCase>(
  (ref) => PublishItineraryUseCase(ref.watch(socialRepositoryProvider)),
);

final fetchExplorePostsUseCaseProvider = Provider<FetchExplorePostsUseCase>(
  (ref) => FetchExplorePostsUseCase(ref.watch(socialRepositoryProvider)),
);

final fetchFollowingFeedUseCaseProvider = Provider<FetchFollowingFeedUseCase>(
  (ref) => FetchFollowingFeedUseCase(ref.watch(socialRepositoryProvider)),
);

final fetchPostsByAuthorUseCaseProvider = Provider<FetchPostsByAuthorUseCase>(
  (ref) => FetchPostsByAuthorUseCase(ref.watch(socialRepositoryProvider)),
);

final forkPostUseCaseProvider = Provider<ForkPostUseCase>(
  (ref) => ForkPostUseCase(ref.watch(socialRepositoryProvider)),
);

final toggleLikeUseCaseProvider = Provider<ToggleLikeUseCase>(
  (ref) => ToggleLikeUseCase(ref.watch(socialRepositoryProvider)),
);

final toggleFollowUseCaseProvider = Provider<ToggleFollowUseCase>(
  (ref) => ToggleFollowUseCase(ref.watch(socialRepositoryProvider)),
);

final fetchFollowStatsUseCaseProvider = Provider<FetchFollowStatsUseCase>(
  (ref) => FetchFollowStatsUseCase(ref.watch(socialRepositoryProvider)),
);

// ── Reads ────────────────────────────────────────────────────────────────────

/// All public posts, optionally filtered by a search term. Keyed by the
/// (trimmed, nullable-if-empty) query so typing a new search term reads a
/// fresh provider instance instead of needing manual invalidation.
final explorePostsProvider = FutureProvider.autoDispose
    .family<List<ItineraryPost>, String?>((ref, query) async {
      final result = await ref
          .read(fetchExplorePostsUseCaseProvider)
          .call(query: query);
      return result.fold((f) => throw Exception(f.message), (posts) => posts);
    });

/// Posts from authors the current user follows. Empty (not an error) when
/// signed out or following nobody yet.
final followingFeedProvider = FutureProvider.autoDispose<List<ItineraryPost>>((
  ref,
) async {
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) {
    return [];
  }

  final result = await ref
      .read(fetchFollowingFeedUseCaseProvider)
      .call(currentUserId: auth.user.id);
  return result.fold((f) => throw Exception(f.message), (posts) => posts);
});

/// All posts by a given author, newest first — used on the public profile page.
final authorPostsProvider = FutureProvider.autoDispose
    .family<List<ItineraryPost>, String>((ref, authorId) async {
      final result = await ref
          .read(fetchPostsByAuthorUseCaseProvider)
          .call(authorId);
      return result.fold((f) => throw Exception(f.message), (posts) => posts);
    });

/// Follow counts + whether the current user follows the given user id.
final followStatsProvider = FutureProvider.autoDispose
    .family<FollowStats?, String>((ref, userId) async {
      final auth = ref.watch(authNotifierProvider);
      if (auth is! AuthAuthenticated) {
        return null;
      }

      final result = await ref
          .read(fetchFollowStatsUseCaseProvider)
          .call(userId: userId, currentUserId: auth.user.id);
      return result.fold((f) => throw Exception(f.message), (stats) => stats);
    });
