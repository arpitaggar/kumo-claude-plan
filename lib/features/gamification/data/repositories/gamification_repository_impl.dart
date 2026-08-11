import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/xp_event.dart';
import '../../domain/repositories/gamification_repository.dart';
import '../datasources/gamification_remote_datasource.dart';

class GamificationRepositoryImpl implements GamificationRepository {
  const GamificationRepositoryImpl(this._remoteDataSource);

  final GamificationRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<XpEvent>>> fetchXpEvents(String userId) async {
    try {
      final events = await _remoteDataSource.fetchXpEvents(userId);
      return Right(events);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
