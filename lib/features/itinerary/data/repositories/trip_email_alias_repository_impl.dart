import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/trip_email_alias.dart';
import '../../domain/repositories/trip_email_alias_repository.dart';
import '../datasources/trip_email_alias_remote_datasource.dart';

class TripEmailAliasRepositoryImpl implements TripEmailAliasRepository {
  const TripEmailAliasRepositoryImpl({required this.dataSource});

  final TripEmailAliasRemoteDataSource dataSource;

  @override
  Future<Either<Failure, TripEmailAlias>> getAlias(String itineraryId) async {
    try {
      final alias = await dataSource.fetchAlias(itineraryId);
      return Right(alias);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
