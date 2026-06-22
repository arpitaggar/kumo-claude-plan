import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../domain/repositories/discover_repository.dart';
import '../datasources/discover_remote_datasource.dart';

class DiscoverRepositoryImpl implements DiscoverRepository {
  const DiscoverRepositoryImpl(this._dataSource);

  final DiscoverRemoteDataSource _dataSource;

  @override
  Future<Either<Failure, List<TravelItinerary>>> fetchPublicItineraries({
    String? query,
  }) async {
    try {
      final results = await _dataSource.fetchPublicItineraries(query: query);
      return Right(results);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(UnexpectedFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TravelItinerary>> cloneItinerary({
    required String itineraryId,
    required String newOwnerId,
    required String newOwnerName,
  }) async {
    try {
      final cloned = await _dataSource.cloneItinerary(
        itineraryId: itineraryId,
        newOwnerId: newOwnerId,
        newOwnerName: newOwnerName,
      );
      return Right(cloned);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(UnexpectedFailure(e.message));
    }
  }
}
