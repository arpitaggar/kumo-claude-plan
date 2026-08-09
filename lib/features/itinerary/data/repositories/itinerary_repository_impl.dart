import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../../domain/repositories/itinerary_repository.dart';
import '../datasources/itinerary_local_datasource.dart';
import '../datasources/itinerary_remote_datasource.dart';
import '../models/itinerary_model.dart';

class ItineraryRepositoryImpl implements ItineraryRepository {
  const ItineraryRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final ItineraryRemoteDataSource remoteDataSource;
  final ItineraryLocalDataSource localDataSource;

  @override
  Future<Either<Failure, List<TravelItinerary>>> fetchItineraries(
    String userId,
  ) async {
    try {
      final result = await remoteDataSource.fetchItineraries(userId);
      await localDataSource.saveItineraries(userId, result);
      return Right(result);
    } on ServerException catch (e) {
      final cached = await localDataSource.loadCached(userId);
      if (cached != null) {
        return Right(cached);
      }
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      final cached = await localDataSource.loadCached(userId);
      if (cached != null) {
        return Right(cached);
      }
      return Left(NetworkFailure(e.message));
    } catch (e) {
      final cached = await localDataSource.loadCached(userId);
      if (cached != null) {
        return Right(cached);
      }
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TravelItinerary>> fetchItinerary(String id) async {
    try {
      final result = await remoteDataSource.fetchItinerary(id);
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
  Future<Either<Failure, TravelItinerary>> createItinerary(
    TravelItinerary itinerary,
  ) async {
    try {
      final model = ItineraryModel.fromEntity(itinerary);
      final result = await remoteDataSource.createItinerary(model);
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
  Future<Either<Failure, TravelItinerary>> updateItinerary(
    TravelItinerary itinerary,
  ) async {
    try {
      final model = ItineraryModel.fromEntity(itinerary);
      final result = await remoteDataSource.updateItinerary(model);
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
  Future<Either<Failure, void>> deleteItinerary(String id) async {
    try {
      await remoteDataSource.deleteItinerary(id);
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
  Stream<Either<Failure, TravelItinerary>> watchItinerary(String id) =>
      remoteDataSource
          .watchItinerary(id)
          .transform(
            // `Stream.handleError`'s callback return value is silently
            // discarded — it only suppresses the error, it can't inject a
            // replacement event. A `StreamTransformer` sink is the only way to
            // turn an upstream stream error into a `Left(...)` value.
            StreamTransformer.fromHandlers(
              handleData: (data, sink) => sink.add(Right(data)),
              handleError: (error, stackTrace, sink) => sink.add(
                Left<Failure, TravelItinerary>(
                  error is ServerException
                      ? ServerFailure(error.message)
                      : UnexpectedFailure(error.toString()),
                ),
              ),
            ),
          );
}
