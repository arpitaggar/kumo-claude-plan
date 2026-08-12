import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:kumo_claude/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kumo_claude/features/auth/data/models/user_model.dart';
import 'package:kumo_claude/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

void main() {
  late MockAuthRemoteDataSource remote;
  late MockAuthLocalDataSource local;
  late AuthRepositoryImpl repository;

  final tUser = UserModel(
    id: 'user-1',
    email: 'me@example.com',
    createdAt: DateTime.utc(2026, 1, 1),
  );
  final tAdultDob = DateTime.now().subtract(const Duration(days: 365 * 30));

  setUpAll(() {
    registerFallbackValue(tUser);
    registerFallbackValue(tAdultDob);
  });

  setUp(() {
    remote = MockAuthRemoteDataSource();
    local = MockAuthLocalDataSource();
    repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
    );
  });

  group('signUp', () {
    test('returns Right(user) and caches it on success', () async {
      when(
        () => remote.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          dateOfBirth: any(named: 'dateOfBirth'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => tUser);
      when(() => local.cacheUser(any())).thenAnswer((_) async {});

      final result = await repository.signUp(
        email: 'me@example.com',
        password: 'password123',
        dateOfBirth: tAdultDob,
      );

      verify(() => local.cacheUser(tUser)).called(1);
      result.fold((_) => fail('expected Right'), (user) => expect(user, tUser));
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => remote.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          dateOfBirth: any(named: 'dateOfBirth'),
          displayName: any(named: 'displayName'),
        ),
      ).thenThrow(AuthException(message: 'email already registered'));

      final result = await repository.signUp(
        email: 'me@example.com',
        password: 'password123',
        dateOfBirth: tAdultDob,
      );

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps NetworkException to NetworkFailure', () async {
      when(
        () => remote.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          dateOfBirth: any(named: 'dateOfBirth'),
          displayName: any(named: 'displayName'),
        ),
      ).thenThrow(NetworkException.noInternet());

      final result = await repository.signUp(
        email: 'me@example.com',
        password: 'password123',
        dateOfBirth: tAdultDob,
      );

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('on a cache-write failure, falls back to a live getCurrentUser() '
        'read instead of failing the whole sign-up', () async {
      when(
        () => remote.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          dateOfBirth: any(named: 'dateOfBirth'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => tUser);
      when(
        () => local.cacheUser(any()),
      ).thenThrow(LocalStorageException.failedToSave());
      when(() => remote.getCurrentUser()).thenAnswer((_) async => tUser);

      final result = await repository.signUp(
        email: 'me@example.com',
        password: 'password123',
        dateOfBirth: tAdultDob,
      );

      result.fold((_) => fail('expected Right'), (user) => expect(user, tUser));
    });

    test('returns Left(UnexpectedFailure) when the cache-write fallback finds '
        'no current user', () async {
      when(
        () => remote.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          dateOfBirth: any(named: 'dateOfBirth'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => tUser);
      when(
        () => local.cacheUser(any()),
      ).thenThrow(LocalStorageException.failedToSave());
      when(() => remote.getCurrentUser()).thenAnswer((_) async => null);

      final result = await repository.signUp(
        email: 'me@example.com',
        password: 'password123',
        dateOfBirth: tAdultDob,
      );

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('completes with a Left instead of throwing when the cache-write '
        "fallback's own getCurrentUser() call also throws", () async {
      // Regression test: the fallback used to call remote.getCurrentUser()
      // unguarded inside the LocalStorageException catch clause — a throw
      // from inside a catch block isn't caught by that same try's other
      // clauses, so this used to escape signUp() entirely instead of
      // resolving to a Left, breaking the Either<Failure,T> contract.
      when(
        () => remote.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          dateOfBirth: any(named: 'dateOfBirth'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => tUser);
      when(
        () => local.cacheUser(any()),
      ).thenThrow(LocalStorageException.failedToSave());
      when(
        () => remote.getCurrentUser(),
      ).thenThrow(NetworkException.noInternet());

      final result = await repository.signUp(
        email: 'me@example.com',
        password: 'password123',
        dateOfBirth: tAdultDob,
      );

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('login', () {
    test('returns Right(user) and caches it on success', () async {
      when(
        () => remote.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => tUser);
      when(() => local.cacheUser(any())).thenAnswer((_) async {});

      final result = await repository.login(
        email: 'me@example.com',
        password: 'password123',
      );

      verify(() => local.cacheUser(tUser)).called(1);
      result.fold((_) => fail('expected Right'), (user) => expect(user, tUser));
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => remote.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(AuthException.invalidCredentials());

      final result = await repository.login(
        email: 'me@example.com',
        password: 'wrong',
      );

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'on a cache-write failure, falls back to a live getCurrentUser() read',
      () async {
        when(
          () => remote.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => tUser);
        when(
          () => local.cacheUser(any()),
        ).thenThrow(LocalStorageException.failedToSave());
        when(() => remote.getCurrentUser()).thenAnswer((_) async => tUser);

        final result = await repository.login(
          email: 'me@example.com',
          password: 'password123',
        );

        result.fold(
          (_) => fail('expected Right'),
          (user) => expect(user, tUser),
        );
      },
    );

    test(
      'completes with a Left instead of throwing when the fallback getCurrentUser() '
      'call also throws',
      () async {
        when(
          () => remote.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => tUser);
        when(
          () => local.cacheUser(any()),
        ).thenThrow(LocalStorageException.failedToSave());
        when(
          () => remote.getCurrentUser(),
        ).thenThrow(AuthException.sessionExpired());

        final result = await repository.login(
          email: 'me@example.com',
          password: 'password123',
        );

        result.fold(
          (f) => expect(f, isA<AuthFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('logout', () {
    test('clears the cache and returns Right(null) on success', () async {
      when(() => remote.logout()).thenAnswer((_) async {});
      when(() => local.clearCachedUser()).thenAnswer((_) async {});

      final result = await repository.logout();

      verify(() => local.clearCachedUser()).called(1);
      expect(result, const Right<Failure, void>(null));
    });

    test('maps AuthException to AuthFailure', () async {
      when(() => remote.logout()).thenThrow(AuthException.sessionExpired());

      final result = await repository.logout();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('refreshSession', () {
    test('returns Right(user) and caches it on success', () async {
      when(() => remote.refreshSession()).thenAnswer((_) async => tUser);
      when(() => local.cacheUser(any())).thenAnswer((_) async {});

      final result = await repository.refreshSession();

      result.fold((_) => fail('expected Right'), (user) => expect(user, tUser));
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => remote.refreshSession(),
      ).thenThrow(AuthException.sessionExpired());

      final result = await repository.refreshSession();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('sendPasswordResetEmail', () {
    test('returns Right(null) on success', () async {
      when(() => remote.sendPasswordResetEmail(any())).thenAnswer((_) async {});

      final result = await repository.sendPasswordResetEmail('me@example.com');

      expect(result, const Right<Failure, void>(null));
    });

    test('maps NetworkException to NetworkFailure', () async {
      when(
        () => remote.sendPasswordResetEmail(any()),
      ).thenThrow(NetworkException.timeout());

      final result = await repository.sendPasswordResetEmail('me@example.com');

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('resetPassword', () {
    test('returns Right(null) on success', () async {
      when(
        () => remote.resetPassword(newPassword: any(named: 'newPassword')),
      ).thenAnswer((_) async {});

      final result = await repository.resetPassword(newPassword: 'newpass1');

      expect(result, const Right<Failure, void>(null));
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => remote.resetPassword(newPassword: any(named: 'newPassword')),
      ).thenThrow(AuthException(message: 'weak password'));

      final result = await repository.resetPassword(newPassword: '123');

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('getCurrentUser', () {
    test('caches and returns the remote user when present', () async {
      when(() => remote.getCurrentUser()).thenAnswer((_) async => tUser);
      when(() => local.cacheUser(any())).thenAnswer((_) async {});

      final result = await repository.getCurrentUser();

      verify(() => local.cacheUser(tUser)).called(1);
      result.fold((_) => fail('expected Right'), (user) => expect(user, tUser));
    });

    test(
      'falls back to the cached user when the remote call finds none',
      () async {
        when(() => remote.getCurrentUser()).thenAnswer((_) async => null);
        when(() => local.getCachedUser()).thenAnswer((_) async => tUser);

        final result = await repository.getCurrentUser();

        result.fold(
          (_) => fail('expected Right'),
          (user) => expect(user, tUser),
        );
      },
    );

    test('maps LocalStorageException to LocalStorageFailure', () async {
      when(
        () => remote.getCurrentUser(),
      ).thenThrow(LocalStorageException.failedToRead());

      final result = await repository.getCurrentUser();

      result.fold(
        (f) => expect(f, isA<LocalStorageFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateProfile', () {
    test('returns Right(user) and re-caches the profile on success', () async {
      when(
        () => remote.updateProfile(
          displayName: any(named: 'displayName'),
          avatarUrl: any(named: 'avatarUrl'),
        ),
      ).thenAnswer((_) async => tUser);
      when(() => local.cacheUser(any())).thenAnswer((_) async {});

      final result = await repository.updateProfile(displayName: 'New Name');

      verify(() => local.cacheUser(any())).called(1);
      result.fold((_) => fail('expected Right'), (user) => expect(user, tUser));
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => remote.updateProfile(
          displayName: any(named: 'displayName'),
          avatarUrl: any(named: 'avatarUrl'),
        ),
      ).thenThrow(AuthException.sessionExpired());

      final result = await repository.updateProfile(displayName: 'New Name');

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('verifyEmail', () {
    test('returns Right(null) on success', () async {
      when(() => remote.verifyEmail(any())).thenAnswer((_) async {});

      final result = await repository.verifyEmail('token-1');

      expect(result, const Right<Failure, void>(null));
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => remote.verifyEmail(any()),
      ).thenThrow(AuthException(message: 'invalid token'));

      final result = await repository.verifyEmail('token-1');

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('isAuthenticated', () {
    test('delegates to the remote data source', () {
      when(() => remote.isAuthenticated()).thenReturn(true);

      expect(repository.isAuthenticated(), isTrue);
      verify(() => remote.isAuthenticated()).called(1);
    });
  });

  group('deleteAccount', () {
    test('clears the cache and returns Right(null) on success', () async {
      when(() => remote.deleteAccount()).thenAnswer((_) async {});
      when(() => local.clearCachedUser()).thenAnswer((_) async {});

      final result = await repository.deleteAccount();

      verify(() => local.clearCachedUser()).called(1);
      expect(result, const Right<Failure, void>(null));
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => remote.deleteAccount(),
      ).thenThrow(AuthException.sessionExpired());

      final result = await repository.deleteAccount();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('exportOwnData', () {
    test('returns Right(data) on success', () async {
      final data = <String, dynamic>{
        'profile': {'id': 'user-1'},
      };
      when(() => remote.exportOwnData()).thenAnswer((_) async => data);

      final result = await repository.exportOwnData();

      result.fold((_) => fail('expected Right'), (d) => expect(d, data));
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => remote.exportOwnData(),
      ).thenThrow(AuthException.sessionExpired());

      final result = await repository.exportOwnData();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps unexpected errors to UnexpectedFailure', () async {
      when(() => remote.exportOwnData()).thenThrow(Exception('boom'));

      final result = await repository.exportOwnData();

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('confirmAge', () {
    final tDob = DateTime(1990, 1, 1);

    test('returns Right(true) when the datasource reports verified', () async {
      when(() => remote.confirmAge(tDob)).thenAnswer((_) async => true);

      final result = await repository.confirmAge(tDob);

      result.fold((_) => fail('expected Right'), (v) => expect(v, isTrue));
    });

    test('returns Right(false) when the datasource reports rejected', () async {
      when(() => remote.confirmAge(tDob)).thenAnswer((_) async => false);

      final result = await repository.confirmAge(tDob);

      result.fold((_) => fail('expected Right'), (v) => expect(v, isFalse));
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => remote.confirmAge(any()),
      ).thenThrow(AuthException.sessionExpired());

      final result = await repository.confirmAge(tDob);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps unexpected errors to UnexpectedFailure', () async {
      when(() => remote.confirmAge(any())).thenThrow(Exception('boom'));

      final result = await repository.confirmAge(tDob);

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
