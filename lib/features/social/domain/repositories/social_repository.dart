import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../../itinerary/domain/entities/trip_segment.dart';
import '../entities/follow_stats.dart';
import '../entities/itinerary_post.dart';

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
  /// title/description.
  Future<Either<Failure, List<ItineraryPost>>> fetchExplore({String? query});

  /// Posts authored by anyone [currentUserId] follows, newest first.
  Future<Either<Failure, List<ItineraryPost>>> fetchFeed({
    required String currentUserId,
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
}
