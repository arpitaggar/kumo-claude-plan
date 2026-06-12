import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../../domain/repositories/itinerary_repository.dart';
import '../datasources/itinerary_remote_datasource.dart';
import '../models/itinerary_model.dart';

class ItineraryRepositoryImpl implements ItineraryRepository {
  const ItineraryRepositoryImpl({required this.remoteDataSource});

  final ItineraryRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<TravelItinerary>>> fetchItineraries(
    String userId,
  ) async {
    try {
      final result = await remoteDataSource.fetchItineraries(userId);
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
          .map<Either<Failure, TravelItinerary>>(Right.new)
          .handleError(
            (Object e) => Left<Failure, TravelItinerary>(
              e is ServerException
                  ? ServerFailure(e.message)
                  : UnexpectedFailure(e.toString()),
            ),
          );
}
