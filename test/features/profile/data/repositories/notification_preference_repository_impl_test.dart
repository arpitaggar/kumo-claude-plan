import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/profile/data/datasources/notification_preference_remote_datasource.dart';
import 'package:kumo_claude/features/profile/data/models/notification_preference_model.dart';
import 'package:kumo_claude/features/profile/data/repositories/notification_preference_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationPreferenceRemoteDataSource extends Mock
    implements NotificationPreferenceRemoteDataSource {}

void main() {
  late MockNotificationPreferenceRemoteDataSource dataSource;
  late NotificationPreferenceRepositoryImpl repository;

  const tPreference = NotificationPreferenceModel(
    channel: 'push',
    category: 'trip_invites',
    enabled: true,
  );

  setUp(() {
    dataSource = MockNotificationPreferenceRemoteDataSource();
    repository = NotificationPreferenceRepositoryImpl(dataSource);
  });

  group('getNotificationPreferences', () {
    test('returns Right(preferences) on success', () async {
      when(
        dataSource.getNotificationPreferences,
      ).thenAnswer((_) async => [tPreference]);

      final result = await repository.getNotificationPreferences();

      result.fold(
        (_) => fail('expected Right'),
        (prefs) => expect(prefs, [tPreference]),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        dataSource.getNotificationPreferences,
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.getNotificationPreferences();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps UnexpectedException to ServerFailure', () async {
      when(
        dataSource.getNotificationPreferences,
      ).thenThrow(UnexpectedException(message: 'boom'));

      final result = await repository.getNotificationPreferences();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('upsertNotificationPreference', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.upsertNotificationPreference(
          channel: 'push',
          category: 'trip_invites',
          enabled: false,
        ),
      ).thenAnswer((_) async {});

      final result = await repository.upsertNotificationPreference(
        channel: 'push',
        category: 'trip_invites',
        enabled: false,
      );

      expect(result, const Right<Failure, void>(null));
      verify(
        () => dataSource.upsertNotificationPreference(
          channel: 'push',
          category: 'trip_invites',
          enabled: false,
        ),
      ).called(1);
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => dataSource.upsertNotificationPreference(
          channel: any(named: 'channel'),
          category: any(named: 'category'),
          enabled: any(named: 'enabled'),
        ),
      ).thenThrow(AuthException(message: 'not signed in'));

      final result = await repository.upsertNotificationPreference(
        channel: 'push',
        category: 'trip_invites',
        enabled: true,
      );

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.upsertNotificationPreference(
          channel: any(named: 'channel'),
          category: any(named: 'category'),
          enabled: any(named: 'enabled'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.upsertNotificationPreference(
        channel: 'push',
        category: 'trip_invites',
        enabled: true,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
