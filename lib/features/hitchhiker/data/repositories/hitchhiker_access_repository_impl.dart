import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/hitchhiker_trip_view.dart';
import '../../domain/repositories/hitchhiker_access_repository.dart';
import '../datasources/hitchhiker_access_remote_datasource.dart';

class HitchhikerAccessRepositoryImpl implements HitchhikerAccessRepository {
  const HitchhikerAccessRepositoryImpl(this._remoteDataSource);

  final HitchhikerAccessRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, HitchhikerTripView>> getTripView(String token) async {
    try {
      final view = await _remoteDataSource.getTripView(token);
      return Right(view);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendMessage({
    required String token,
    required String content,
  }) async {
    try {
      await _remoteDataSource.sendMessage(token: token, content: content);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> suggestItem({
    required String token,
    required String title,
    String? description,
  }) async {
    try {
      await _remoteDataSource.suggestItem(
        token: token,
        title: title,
        description: description,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
