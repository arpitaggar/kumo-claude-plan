import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl(this._remoteDataSource);

  final NotificationsRemoteDataSource _remoteDataSource;

  @override
  Stream<Either<Failure, List<AppNotification>>> watchNotifications(
    String userId,
  ) => _remoteDataSource
      .watchNotifications(userId)
      .transform(
        // `Stream.handleError`'s callback return value is silently
        // discarded — see the fix note on the other 6 watch* repositories
        // (chat/packing/expense/itinerary/trip_segment/rating) for why a
        // StreamTransformer sink, not .handleError, is required to turn an
        // upstream error into a Left(...) value instead of dropping it.
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
  Future<Either<Failure, void>> markAllRead(String userId) async {
    try {
      await _remoteDataSource.markAllRead(userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
