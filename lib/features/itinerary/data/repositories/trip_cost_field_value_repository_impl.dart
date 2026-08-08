import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/trip_cost_field_value.dart';
import '../../domain/repositories/trip_cost_field_value_repository.dart';
import '../datasources/trip_cost_field_value_remote_datasource.dart';

class TripCostFieldValueRepositoryImpl implements TripCostFieldValueRepository {
  const TripCostFieldValueRepositoryImpl({required this.dataSource});

  final TripCostFieldValueRemoteDataSource dataSource;

  @override
  Future<Either<Failure, List<TripCostFieldValue>>> fetchValues(
    String itineraryId,
  ) async {
    try {
      final values = await dataSource.fetchValues(itineraryId);
      return Right(values);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setValues(
    String itineraryId,
    Map<String, String> fieldIdToOptionId,
  ) async {
    try {
      await dataSource.setValues(itineraryId, fieldIdToOptionId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
