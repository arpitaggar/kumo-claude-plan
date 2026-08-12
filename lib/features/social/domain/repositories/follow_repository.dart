import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/follow_stats.dart';

/// Split out of `SocialRepository` — the follow graph is a separable
/// concern from posts/forks/comments (no single consumer needs both; e.g.
/// `DiscoverPage` never touches follow state directly, and the follow
/// toggle on `PublicProfilePage` doesn't need `SocialRepository`'s post
/// methods).
abstract class FollowRepository {
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
