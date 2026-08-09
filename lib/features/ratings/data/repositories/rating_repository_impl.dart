import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/rating.dart';
import '../../domain/repositories/rating_repository.dart';
import '../datasources/rating_remote_datasource.dart';
import '../models/rating_model.dart';

class RatingRepositoryImpl implements RatingRepository {
  const RatingRepositoryImpl({required this.dataSource});

  final RatingRemoteDataSource dataSource;

  @override
  Stream<Either<Failure, List<Rating>>> watchRatings(String itineraryId) =>
      dataSource
          .watchRatings(itineraryId)
          .transform(
            // `Stream.handleError`'s callback return value is silently
            // discarded — it only suppresses the error, it can't inject a
            // replacement event. A `StreamTransformer` sink is the only way to
            // turn an upstream stream error into a `Left(...)` value.
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
  Future<Either<Failure, Rating>> addRating(Rating rating) async {
    try {
      final model = RatingModel(
        id: rating.id,
        itineraryId: rating.itineraryId,
        targetName: rating.targetName,
        stars: rating.stars,
        userId: rating.userId,
        userName: rating.userName,
        createdAt: rating.createdAt,
        itemId: rating.itemId,
        comment: rating.comment,
      );
      final saved = await dataSource.addRating(model);
      return Right(saved);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRating(String ratingId) async {
    try {
      await dataSource.deleteRating(ratingId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
