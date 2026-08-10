import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../../itinerary/domain/entities/trip_segment.dart';
import '../entities/follow_stats.dart';
import '../entities/itinerary_post.dart';

/// Default page size for [SocialRepository.fetchExplore]/[SocialRepository.fetchFeed] —
/// defined here (domain) rather than in the data layer's datasource, since
/// the data layer is allowed to depend on domain but never the reverse.
const kSocialFeedPageSize = 20;

abstract class SocialRepository {
  /// Snapshots [itinerary] + [segments] into a new, immutable [ItineraryPost].
  /// If `itinerary.originPostId` is set, the new post's `forkedFromPostId`
  /// chains to it automatically.
  Future<Either<Failure, ItineraryPost>> publishItinerary({
    required TravelItinerary itinerary,
    required List<TripSegment> segments,
    required String authorName,
    String? authorAvatarUrl,
  });

  /// All public posts, newest first, optionally filtered by [query] against
  /// title/description (server-side search, not limited to whatever page is
  /// fetched). [before] fetches the page just older than that timestamp —
  /// pass the last returned post's `createdAt` to load the next page; a
  /// result shorter than [limit] means there's no next page.
  Future<Either<Failure, List<ItineraryPost>>> fetchExplore({
    String? query,
    DateTime? before,
    int limit = kSocialFeedPageSize,
  });

  /// Posts authored by anyone [currentUserId] follows, newest first. See
  /// [fetchExplore]'s [before]/[limit] doc for pagination.
  Future<Either<Failure, List<ItineraryPost>>> fetchFeed({
    required String currentUserId,
    DateTime? before,
    int limit = kSocialFeedPageSize,
  });

  /// All posts authored by [authorId], newest first.
  Future<Either<Failure, List<ItineraryPost>>> fetchPostsByAuthor(
    String authorId,
  );

  /// Creates a new private [TravelItinerary] (+ its route segments) for
  /// [newOwnerId] from [postId]'s snapshot, with `originPostId` set so a
  /// later publish of the fork carries "remixed from" lineage.
  Future<Either<Failure, TravelItinerary>> forkPost({
    required String postId,
    required String newOwnerId,
    required String newOwnerName,
  });

  Future<Either<Failure, void>> toggleLike({
    required String postId,
    required String userId,
    required bool like,
  });

  Future<Either<Failure, void>> toggleFollow({
    required String followerId,
    required String followeeId,
    required bool follow,
  });

  Future<Either<Failure, FollowStats>> fetchFollowStats({
    required String userId,
    required String currentUserId,
  });

  /// Deletes [postId]. RLS restricts this to the post's own author — see
  /// `stage36_post_delete.sql`. Forks and likes referencing this post are
  /// not deleted themselves; they just lose the pointer (`on delete set
  /// null`/`cascade`, handled entirely by the migration).
  Future<Either<Failure, void>> deletePost(String postId);
}
