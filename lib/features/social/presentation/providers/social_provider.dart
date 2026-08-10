import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/social_remote_datasource.dart';
import '../../data/repositories/social_repository_impl.dart';
import '../../domain/entities/follow_stats.dart';
import '../../domain/entities/itinerary_post.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/usecases/delete_post_usecase.dart';
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

final deletePostUseCaseProvider = Provider<DeletePostUseCase>(
  (ref) => DeletePostUseCase(ref.watch(socialRepositoryProvider)),
);

// ── Reads ────────────────────────────────────────────────────────────────────

/// A page of posts plus enough state to drive "load more" — see
/// `PostFeedNotifier`. `hasMore` is a heuristic (the last page returned a
/// full page's worth of rows), not a server-confirmed total; good enough for
/// "show the button or don't", not for an exact count.
sealed class PostFeedState {
  const PostFeedState();
}

class PostFeedLoading extends PostFeedState {
  const PostFeedLoading();
}

class PostFeedError extends PostFeedState {
  const PostFeedError(this.message);
  final String message;
}

class PostFeedLoaded extends PostFeedState {
  const PostFeedLoaded(
    this.posts, {
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<ItineraryPost> posts;
  final bool hasMore;
  final bool isLoadingMore;

  PostFeedLoaded copyWith({
    List<ItineraryPost>? posts,
    bool? hasMore,
    bool? isLoadingMore,
  }) => PostFeedLoaded(
    posts ?? this.posts,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// Backs both the Explore and Following feeds — same shape (a keyset-
/// paginated list of posts), just a different fetch call per subclass.
abstract class PostFeedNotifier extends StateNotifier<PostFeedState> {
  PostFeedNotifier() : super(const PostFeedLoading()) {
    _loadFirstPage();
  }

  /// Fetches one page. [before] is null for the first page, otherwise the
  /// last-loaded post's `createdAt` for the next one.
  Future<Either<Failure, List<ItineraryPost>>> fetchPage({DateTime? before});

  Future<void> _loadFirstPage() async {
    state = const PostFeedLoading();
    final result = await fetchPage();
    // A provider that depends on other providers (both concrete subclasses
    // here watch auth state) can be disposed-and-rebuilt mid-fetch — e.g.
    // auth resolving from AuthInitial -> AuthLoading -> AuthAuthenticated
    // on app startup tears this notifier down and recreates it more than
    // once. Without this guard, a stale fetch from an already-disposed
    // instance would throw trying to assign `state` after dispose.
    if (!mounted) {
      return;
    }
    result.fold(
      (failure) => state = PostFeedError(failure.message),
      (posts) => state = PostFeedLoaded(
        posts,
        hasMore: posts.length == kSocialFeedPageSize,
      ),
    );
  }

  /// Re-fetches the first page in place (e.g. after a like toggle) without
  /// dropping into the full-screen loading state.
  Future<void> refresh() async {
    final result = await fetchPage();
    if (!mounted) {
      return;
    }
    result.fold(
      (_) {}, // silent fail — keep showing whatever is currently displayed
      (posts) => state = PostFeedLoaded(
        posts,
        hasMore: posts.length == kSocialFeedPageSize,
      ),
    );
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! PostFeedLoaded ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.posts.isEmpty) {
      return;
    }
    state = current.copyWith(isLoadingMore: true);
    final result = await fetchPage(before: current.posts.last.createdAt);
    if (!mounted) {
      return;
    }
    result.fold(
      (_) => state = current.copyWith(isLoadingMore: false),
      (nextPage) => state = PostFeedLoaded([
        ...current.posts,
        ...nextPage,
      ], hasMore: nextPage.length == kSocialFeedPageSize),
    );
  }
}

class _ExploreFeedNotifier extends PostFeedNotifier {
  _ExploreFeedNotifier({required this.fetchUseCase, required this.query});

  final FetchExplorePostsUseCase fetchUseCase;
  final String? query;

  @override
  Future<Either<Failure, List<ItineraryPost>>> fetchPage({DateTime? before}) =>
      fetchUseCase.call(query: query, before: before);
}

/// All public posts, optionally filtered by a search term (searches the
/// whole feed server-side, not just the currently-loaded page — see
/// stage33's pg_trgm indexes). Keyed by the (trimmed, nullable-if-empty)
/// query so typing a new search term reads a fresh notifier instead of
/// needing manual invalidation.
final explorePostsProvider = StateNotifierProvider.autoDispose
    .family<PostFeedNotifier, PostFeedState, String?>(
      (ref, query) => _ExploreFeedNotifier(
        fetchUseCase: ref.watch(fetchExplorePostsUseCaseProvider),
        query: query,
      ),
    );

class _FollowingFeedNotifier extends PostFeedNotifier {
  _FollowingFeedNotifier({required this.fetchUseCase, this.currentUserId});

  final FetchFollowingFeedUseCase fetchUseCase;
  final String? currentUserId;

  @override
  Future<Either<Failure, List<ItineraryPost>>> fetchPage({
    DateTime? before,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      return const Right([]);
    }
    return fetchUseCase.call(currentUserId: userId, before: before);
  }
}

/// Posts from authors the current user follows. Empty (not an error) when
/// signed out or following nobody yet.
final followingFeedProvider =
    StateNotifierProvider.autoDispose<PostFeedNotifier, PostFeedState>((ref) {
      final auth = ref.watch(authNotifierProvider);
      return _FollowingFeedNotifier(
        fetchUseCase: ref.watch(fetchFollowingFeedUseCaseProvider),
        currentUserId: auth is AuthAuthenticated ? auth.user.id : null,
      );
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
