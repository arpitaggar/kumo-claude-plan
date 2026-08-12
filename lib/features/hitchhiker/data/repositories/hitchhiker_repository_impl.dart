import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/hitchhiker.dart';
import '../../domain/repositories/hitchhiker_repository.dart';
import '../datasources/hitchhiker_remote_datasource.dart';

class HitchhikerRepositoryImpl implements HitchhikerRepository {
  const HitchhikerRepositoryImpl(this._remoteDataSource);

  final HitchhikerRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, Hitchhiker>> createHitchhiker({
    required String itineraryId,
    required String displayName,
  }) async {
    try {
      final hitchhiker = await _remoteDataSource.createHitchhiker(
        itineraryId: itineraryId,
        displayName: displayName,
      );
      return Right(hitchhiker);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> revokeHitchhiker(String hitchhikerId) async {
    try {
      await _remoteDataSource.revokeHitchhiker(hitchhikerId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Hitchhiker>>> listHitchhikers(
    String itineraryId,
  ) async {
    try {
      final hitchhikers = await _remoteDataSource.listHitchhikers(itineraryId);
      return Right(hitchhikers);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
