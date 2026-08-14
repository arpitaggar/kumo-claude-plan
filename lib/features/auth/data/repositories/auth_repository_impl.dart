import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    this.sessionRestoreRetryCount = 10,
    this.sessionRestoreRetryDelay = const Duration(milliseconds: 200),
  });

  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  /// How long [getCurrentUser] waits for a still-in-flight Supabase session
  /// restore before falling back to the offline cache — see that method's
  /// doc comment. Overridable so tests aren't stuck paying the real-time
  /// cost of the production retry budget.
  final int sessionRestoreRetryCount;
  final Duration sessionRestoreRetryDelay;

  @override
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    required DateTime dateOfBirth,
    String? displayName,
  }) async {
    try {
      final user = await remoteDataSource.signUp(
        email: email,
        password: password,
        dateOfBirth: dateOfBirth,
        displayName: displayName,
      );
      await localDataSource.cacheUser(user);
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on LocalStorageException {
      // Cache failure is non-fatal; user still signed up
      return _userAfterCacheFailure();
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.login(
        email: email,
        password: password,
      );
      await localDataSource.cacheUser(user);
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on LocalStorageException {
      // Cache failure is non-fatal; user is still logged in
      return _userAfterCacheFailure();
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  /// Recovers the [Either] result after a [LocalStorageException] during
  /// sign-up/login — the remote auth call already succeeded, only caching
  /// failed, so this re-fetches the user instead of failing the whole
  /// operation. Wrapped in its own try/catch because this call can itself
  /// throw, and a throw from inside a catch block isn't caught by that same
  /// try's other `on`/`catch` clauses.
  Future<Either<Failure, User>> _userAfterCacheFailure() async {
    try {
      final user = await remoteDataSource.getCurrentUser();
      if (user != null) {
        return Right(user);
      }
      return Left(UnexpectedFailure.unknown());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
      await localDataSource.clearCachedUser();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> refreshSession() async {
    try {
      final user = await remoteDataSource.refreshSession();
      await localDataSource.cacheUser(user);
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      await remoteDataSource.sendPasswordResetEmail(email);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String newPassword,
  }) async {
    try {
      await remoteDataSource.resetPassword(newPassword: newPassword);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      var remoteUser = await remoteDataSource.getCurrentUser();
      if (remoteUser == null) {
        // supabase_flutter's session restore from local storage is a real
        // async operation that can still be in flight even after
        // Supabase.initialize()'s own Future has resolved — so a null
        // read here doesn't necessarily mean "logged out," it can mean
        // "not attached yet." Poll briefly for it to catch up before
        // falling back to the offline cache below: without this, a
        // provider that fires its first query in that window (e.g.
        // myOrganizationsProvider) gets treated as anonymous by RLS and
        // permanently caches a wrong empty result for the rest of the
        // session, since a plain FutureProvider never auto-retries. Found
        // via a real-device integration test (2026-08-14) — invisible to
        // mocked flutter test widget tests, which never exercise real
        // Supabase session-restore timing at all.
        for (
          var i = 0;
          i < sessionRestoreRetryCount && remoteUser == null;
          i++
        ) {
          await Future<void>.delayed(sessionRestoreRetryDelay);
          remoteUser = await remoteDataSource.getCurrentUser();
        }
      }
      if (remoteUser != null) {
        await localDataSource.cacheUser(remoteUser);
        return Right(remoteUser);
      }
      final cachedUser = await localDataSource.getCachedUser();
      return Right(cachedUser);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final user = await remoteDataSource.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      await localDataSource.cacheUser(
        UserModel.fromJson({
          'id': user.id,
          'email': user.email,
          'display_name': user.displayName,
          'avatar_url': user.avatarUrl,
          'created_at': user.createdAt.toIso8601String(),
          'last_sign_in_at': user.lastSignInAt?.toIso8601String(),
          'email_verified': user.emailVerified,
          'phone_number': user.phoneNumber,
          'mfa_enabled': user.mfaEnabled,
        }),
      );
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> verifyEmail(String token) async {
    try {
      await remoteDataSource.verifyEmail(token);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  bool isAuthenticated() => remoteDataSource.isAuthenticated();

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await remoteDataSource.deleteAccount();
      await localDataSource.clearCachedUser();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> exportOwnData() async {
    try {
      final data = await remoteDataSource.exportOwnData();
      return Right(data);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> confirmAge(DateTime dateOfBirth) async {
    try {
      final verified = await remoteDataSource.confirmAge(dateOfBirth);
      return Right(verified);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
