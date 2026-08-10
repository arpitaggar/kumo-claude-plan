import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:kumo_claude/features/notifications/data/models/app_notification_model.dart';
import 'package:kumo_claude/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:kumo_claude/features/notifications/domain/entities/app_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRemoteDataSource extends Mock
    implements NotificationsRemoteDataSource {}

void main() {
  late MockNotificationsRemoteDataSource dataSource;
  late NotificationsRepositoryImpl repository;

  final tNotification = AppNotificationModel(
    id: 'n-1',
    actorId: 'actor-1',
    actorName: 'Alice',
    type: NotificationType.follow,
    createdAt: DateTime.utc(2026),
  );

  setUp(() {
    dataSource = MockNotificationsRemoteDataSource();
    repository = NotificationsRepositoryImpl(dataSource);
  });

  group('watchNotifications', () {
    // Same regression class as the other 6 watch* repositories in this app
    // (chat/packing/expense/itinerary/trip_segment/rating/social's own
    // deletePost fix) — Stream.handleError's callback return value is
    // silently discarded, so this must use a StreamTransformer sink, not
    // .handleError, to turn an upstream error into a Left(...).
    test('maps a data-source stream to Right', () async {
      when(
        () => dataSource.watchNotifications('user-1'),
      ).thenAnswer((_) => Stream.value([tNotification]));

      final result = await repository.watchNotifications('user-1').first;

      result.fold(
        (_) => fail('expected Right'),
        (notifications) => expect(notifications, [tNotification]),
      );
    });

    test(
      'maps a stream error to Left(Failure) instead of dropping it',
      () async {
        when(() => dataSource.watchNotifications('user-1')).thenAnswer(
          (_) => Stream<List<AppNotificationModel>>.error(
            ServerException(message: 'connection lost'),
          ),
        );

        final result = await repository.watchNotifications('user-1').first;

        result.fold(
          (f) => expect(f.message, 'connection lost'),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('markAllRead', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.markAllRead('user-1')).thenAnswer((_) async {});

      final result = await repository.markAllRead('user-1');

      expect(result, const Right<Object, void>(null));
      verify(() => dataSource.markAllRead('user-1')).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.markAllRead(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.markAllRead('user-1');

      result.fold(
        (f) => expect(f.message, 'DB error'),
        (_) => fail('expected Left'),
      );
    });
  });
}
