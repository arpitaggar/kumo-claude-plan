import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/follow_stats.dart';
import '../../domain/repositories/follow_repository.dart';
import '../datasources/social_remote_datasource.dart';

/// Shares `SocialRemoteDataSource` with `SocialRepositoryImpl` rather than
/// getting its own datasource — the underlying `follows` table is also read
/// by `fetchFeed` (to resolve which authors' posts to include), so the two
/// concerns are genuinely coupled at the data layer even though they're
/// cleanly separable at the repository/domain layer.
class FollowRepositoryImpl implements FollowRepository {
  const FollowRepositoryImpl(this._remoteDataSource);

  final SocialRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, void>> toggleFollow({
    required String followerId,
    required String followeeId,
    required bool follow,
  }) async {
    try {
      await _remoteDataSource.toggleFollow(
        followerId: followerId,
        followeeId: followeeId,
        follow: follow,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FollowStats>> fetchFollowStats({
    required String userId,
    required String currentUserId,
  }) async {
    try {
      final result = await _remoteDataSource.fetchFollowStats(
        userId: userId,
        currentUserId: currentUserId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
