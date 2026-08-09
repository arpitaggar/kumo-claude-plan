import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../../itinerary/domain/entities/trip_segment.dart';
import '../../domain/entities/follow_stats.dart';
import '../../domain/entities/itinerary_post.dart';
import '../../domain/repositories/social_repository.dart';
import '../datasources/social_remote_datasource.dart';
import '../models/itinerary_post_model.dart';

class SocialRepositoryImpl implements SocialRepository {
  const SocialRepositoryImpl(this._remoteDataSource);

  final SocialRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, ItineraryPost>> publishItinerary({
    required TravelItinerary itinerary,
    required List<TripSegment> segments,
    required String authorName,
    String? authorAvatarUrl,
  }) async {
    try {
      final insertJson = ItineraryPostModel.buildInsertJson(
        itinerary: itinerary,
        segments: segments,
        authorId: itinerary.ownerId,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
      );
      final result = await _remoteDataSource.publishItinerary(insertJson);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ItineraryPost>>> fetchExplore({
    String? query,
    DateTime? before,
    int limit = kSocialFeedPageSize,
  }) async {
    try {
      final currentUserId = _remoteDataSource.currentUserId;
      final result = await _remoteDataSource.fetchExplore(
        currentUserId: currentUserId,
        query: query,
        before: before,
        limit: limit,
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

  @override
  Future<Either<Failure, List<ItineraryPost>>> fetchFeed({
    required String currentUserId,
    DateTime? before,
    int limit = kSocialFeedPageSize,
  }) async {
    try {
      final result = await _remoteDataSource.fetchFeed(
        currentUserId: currentUserId,
        before: before,
        limit: limit,
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

  @override
  Future<Either<Failure, List<ItineraryPost>>> fetchPostsByAuthor(
    String authorId,
  ) async {
    try {
      final currentUserId = _remoteDataSource.currentUserId;
      final result = await _remoteDataSource.fetchPostsByAuthor(
        authorId: authorId,
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

  @override
  Future<Either<Failure, TravelItinerary>> forkPost({
    required String postId,
    required String newOwnerId,
    required String newOwnerName,
  }) async {
    try {
      final result = await _remoteDataSource.forkPost(
        postId: postId,
        newOwnerId: newOwnerId,
        newOwnerName: newOwnerName,
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

  @override
  Future<Either<Failure, void>> toggleLike({
    required String postId,
    required String userId,
    required bool like,
  }) async {
    try {
      await _remoteDataSource.toggleLike(
        postId: postId,
        userId: userId,
        like: like,
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
