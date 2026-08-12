import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/notification_preference.dart';
import '../../domain/repositories/notification_preference_repository.dart';
import '../datasources/notification_preference_remote_datasource.dart';

class NotificationPreferenceRepositoryImpl
    implements NotificationPreferenceRepository {
  const NotificationPreferenceRepositoryImpl(this._remote);

  final NotificationPreferenceRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<NotificationPreference>>>
  getNotificationPreferences() async {
    try {
      return Right(await _remote.getNotificationPreferences());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> upsertNotificationPreference({
    required String channel,
    required String category,
    required bool enabled,
  }) async {
    try {
      await _remote.upsertNotificationPreference(
        channel: channel,
        category: category,
        enabled: enabled,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
