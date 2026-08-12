import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/profile/data/datasources/user_profile_remote_datasource.dart';
import 'package:kumo_claude/features/profile/data/models/user_profile_model.dart';
import 'package:kumo_claude/features/profile/data/repositories/user_profile_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockUserProfileRemoteDataSource extends Mock
    implements UserProfileRemoteDataSource {}

void main() {
  late MockUserProfileRemoteDataSource dataSource;
  late UserProfileRepositoryImpl repository;

  final tProfile = UserProfileModel(
    id: 'user-1',
    email: 'alice@example.com',
    displayName: 'Alice',
    isSearchable: true,
    profileVisibility: 'public',
    contactVisibility: 'collaborators_only',
    unitsPreference: 'metric',
    travelPreferenceTags: const [],
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    dataSource = MockUserProfileRemoteDataSource();
    repository = UserProfileRepositoryImpl(dataSource);
  });

  // Every method on this repository maps the same three exception types the
  // same way (AuthException -> AuthFailure, ServerException/
  // UnexpectedException -> ServerFailure) — covered once per method below,
  // matching the shape actually implemented rather than assuming a generic
  // helper exists.

  group('getOwnProfile', () {
    test('returns Right(profile) on success', () async {
      when(dataSource.getOwnProfile).thenAnswer((_) async => tProfile);

      final result = await repository.getOwnProfile();

      result.fold(
        (_) => fail('expected Right'),
        (profile) => expect(profile, tProfile),
      );
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        dataSource.getOwnProfile,
      ).thenThrow(AuthException(message: 'not signed in'));

      final result = await repository.getOwnProfile();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        dataSource.getOwnProfile,
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.getOwnProfile();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps UnexpectedException to ServerFailure', () async {
      when(
        dataSource.getOwnProfile,
      ).thenThrow(UnexpectedException(message: 'boom'));

      final result = await repository.getOwnProfile();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('getProfileById', () {
    test('returns Right(profile) on success', () async {
      when(
        () => dataSource.getProfileById('user-2'),
      ).thenAnswer((_) async => tProfile);

      final result = await repository.getProfileById('user-2');

      result.fold(
        (_) => fail('expected Right'),
        (profile) => expect(profile, tProfile),
      );
      verify(() => dataSource.getProfileById('user-2')).called(1);
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => dataSource.getProfileById(any()),
      ).thenThrow(AuthException(message: 'not signed in'));

      final result = await repository.getProfileById('user-2');

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.getProfileById(any()),
      ).thenThrow(ServerException(message: 'not found'));

      final result = await repository.getProfileById('user-2');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateProfile', () {
    test(
      'forwards every field and returns Right(profile) on success',
      () async {
        when(
          () => dataSource.updateProfile(
            displayName: any(named: 'displayName'),
            username: any(named: 'username'),
            bio: any(named: 'bio'),
            city: any(named: 'city'),
            country: any(named: 'country'),
            timezone: any(named: 'timezone'),
            preferredCurrency: any(named: 'preferredCurrency'),
            preferredLanguage: any(named: 'preferredLanguage'),
            unitsPreference: any(named: 'unitsPreference'),
            travelPreferenceTags: any(named: 'travelPreferenceTags'),
            profileVisibility: any(named: 'profileVisibility'),
            contactVisibility: any(named: 'contactVisibility'),
            avatarUrl: any(named: 'avatarUrl'),
            pushMessagePreviewEnabled: any(named: 'pushMessagePreviewEnabled'),
          ),
        ).thenAnswer((_) async => tProfile);

        final result = await repository.updateProfile(
          displayName: 'Alice B',
          username: 'aliceb',
        );

        result.fold(
          (_) => fail('expected Right'),
          (profile) => expect(profile, tProfile),
        );
        verify(
          () => dataSource.updateProfile(
            displayName: 'Alice B',
            username: 'aliceb',
            bio: null,
            city: null,
            country: null,
            timezone: null,
            preferredCurrency: null,
            preferredLanguage: null,
            unitsPreference: null,
            travelPreferenceTags: null,
            profileVisibility: null,
            contactVisibility: null,
            avatarUrl: null,
            pushMessagePreviewEnabled: null,
          ),
        ).called(1);
      },
    );

    test('maps AuthException to AuthFailure', () async {
      when(
        () => dataSource.updateProfile(
          displayName: any(named: 'displayName'),
          username: any(named: 'username'),
          bio: any(named: 'bio'),
          city: any(named: 'city'),
          country: any(named: 'country'),
          timezone: any(named: 'timezone'),
          preferredCurrency: any(named: 'preferredCurrency'),
          preferredLanguage: any(named: 'preferredLanguage'),
          unitsPreference: any(named: 'unitsPreference'),
          travelPreferenceTags: any(named: 'travelPreferenceTags'),
          profileVisibility: any(named: 'profileVisibility'),
          contactVisibility: any(named: 'contactVisibility'),
          avatarUrl: any(named: 'avatarUrl'),
          pushMessagePreviewEnabled: any(named: 'pushMessagePreviewEnabled'),
        ),
      ).thenThrow(AuthException(message: 'not signed in'));

      final result = await repository.updateProfile();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'maps ServerException to ServerFailure (e.g. username taken)',
      () async {
        when(
          () => dataSource.updateProfile(
            displayName: any(named: 'displayName'),
            username: any(named: 'username'),
            bio: any(named: 'bio'),
            city: any(named: 'city'),
            country: any(named: 'country'),
            timezone: any(named: 'timezone'),
            preferredCurrency: any(named: 'preferredCurrency'),
            preferredLanguage: any(named: 'preferredLanguage'),
            unitsPreference: any(named: 'unitsPreference'),
            travelPreferenceTags: any(named: 'travelPreferenceTags'),
            profileVisibility: any(named: 'profileVisibility'),
            contactVisibility: any(named: 'contactVisibility'),
            avatarUrl: any(named: 'avatarUrl'),
            pushMessagePreviewEnabled: any(named: 'pushMessagePreviewEnabled'),
          ),
        ).thenThrow(ServerException(message: 'Username already taken'));

        final result = await repository.updateProfile(username: 'taken');

        result.fold(
          (f) => expect(f.message, 'Username already taken'),
          (_) => fail('expected Left'),
        );
      },
    );
  });
}
