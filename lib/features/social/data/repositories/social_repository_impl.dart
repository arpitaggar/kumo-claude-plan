import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../../itinerary/domain/entities/trip_segment.dart';
import '../../domain/entities/itinerary_post.dart';
import '../../domain/entities/post_comment.dart';
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
  Future<Either<Failure, void>> deletePost(String postId) async {
    try {
      await _remoteDataSource.deletePost(postId);
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
  Stream<Either<Failure, List<PostComment>>> watchComments(String postId) =>
      _remoteDataSource
          .watchComments(postId)
          .transform(
            // Same StreamTransformer-not-.handleError requirement as every
            // other watch* method in this app — see deletePost's sibling
            // repositories (chat/packing/expense/itinerary/trip_segment/
            // rating/notifications) for the shared regression note.
            StreamTransformer.fromHandlers(
              handleData: (data, sink) => sink.add(Right(data)),
              handleError: (error, stackTrace, sink) => sink.add(
                Left(
                  error is ServerException
                      ? ServerFailure(error.message)
                      : UnexpectedFailure(error.toString()),
                ),
              ),
            ),
          );

  @override
  Future<Either<Failure, void>> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
    String? authorAvatarUrl,
  }) async {
    try {
      await _remoteDataSource.addComment({
        'post_id': postId,
        'author_id': authorId,
        'author_name': authorName,
        if (authorAvatarUrl != null) 'author_avatar_url': authorAvatarUrl,
        'content': content,
      });
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
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    try {
      await _remoteDataSource.deleteComment(commentId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
