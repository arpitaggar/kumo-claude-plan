import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepositoryImpl {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

void main() {
  setUpAll(initTestSupabase);

  late MockAuthRepository repository;
  late MockLoginUseCase loginUseCase;
  late MockSignupUseCase signupUseCase;
  late MockLogoutUseCase logoutUseCase;
  late MockDeleteAccountUseCase deleteAccountUseCase;

  final tUser = User(
    id: 'user-1',
    email: 'alice@example.com',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  AuthNotifier buildNotifier({Either<Failure, User?>? currentUser}) {
    when(
      repository.getCurrentUser,
    ).thenAnswer((_) async => currentUser ?? const Right(null));
    return AuthNotifier(
      loginUseCase: loginUseCase,
      signupUseCase: signupUseCase,
      logoutUseCase: logoutUseCase,
      deleteAccountUseCase: deleteAccountUseCase,
      repository: repository,
    );
  }

  setUp(() {
    repository = MockAuthRepository();
    loginUseCase = MockLoginUseCase();
    signupUseCase = MockSignupUseCase();
    logoutUseCase = MockLogoutUseCase();
    deleteAccountUseCase = MockDeleteAccountUseCase();
  });

  group('construction (_checkCurrentUser)', () {
    test('resolves to AuthAuthenticated when a session exists', () async {
      final notifier = buildNotifier(currentUser: Right(tUser));
      addTearDown(notifier.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, isA<AuthAuthenticated>());
      expect((notifier.state as AuthAuthenticated).user, tUser);
    });

    test('resolves to AuthUnauthenticated when no session exists', () async {
      final notifier = buildNotifier(currentUser: const Right(null));
      addTearDown(notifier.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, isA<AuthUnauthenticated>());
    });

    test('resolves to AuthUnauthenticated (not AuthError) when the check '
        'itself fails', () async {
      final notifier = buildNotifier(
        currentUser: const Left(ServerFailure('DB error')),
      );
      addTearDown(notifier.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, isA<AuthUnauthenticated>());
    });
  });

  group('login', () {
    test('sets AuthAuthenticated on success', () async {
      final notifier = buildNotifier();
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        () => loginUseCase(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(tUser));

      await notifier.login(email: 'alice@example.com', password: 'hunter22');

      expect(notifier.state, isA<AuthAuthenticated>());
      expect((notifier.state as AuthAuthenticated).user, tUser);
    });

    test('sets AuthError on failure', () async {
      final notifier = buildNotifier();
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        () => loginUseCase(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(AuthFailure('Invalid credentials')));

      await notifier.login(email: 'alice@example.com', password: 'wrong');

      expect(notifier.state, isA<AuthError>());
      expect((notifier.state as AuthError).message, 'Invalid credentials');
    });
  });

  group('signup', () {
    test('sets AuthAuthenticated on success', () async {
      final notifier = buildNotifier();
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        () => signupUseCase(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => Right(tUser));

      await notifier.signup(email: 'alice@example.com', password: 'hunter22');

      expect(notifier.state, isA<AuthAuthenticated>());
    });

    test('sets AuthError on failure', () async {
      final notifier = buildNotifier();
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        () => signupUseCase(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('Email taken')));

      await notifier.signup(email: 'alice@example.com', password: 'hunter22');

      expect(notifier.state, isA<AuthError>());
      expect((notifier.state as AuthError).message, 'Email taken');
    });
  });

  group('logout', () {
    test('sets AuthUnauthenticated on success', () async {
      final notifier = buildNotifier(currentUser: Right(tUser));
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(logoutUseCase.call).thenAnswer((_) async => const Right(null));

      await notifier.logout();

      expect(notifier.state, isA<AuthUnauthenticated>());
    });

    test('sets AuthError on failure', () async {
      final notifier = buildNotifier(currentUser: Right(tUser));
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        logoutUseCase.call,
      ).thenAnswer((_) async => const Left(ServerFailure('network error')));

      await notifier.logout();

      expect(notifier.state, isA<AuthError>());
    });
  });

  group('updatePassword', () {
    test(
      'logs out and sets AuthUnauthenticated after a successful reset',
      () async {
        final notifier = buildNotifier(currentUser: Right(tUser));
        addTearDown(notifier.dispose);
        await Future<void>.delayed(Duration.zero);
        when(
          () =>
              repository.resetPassword(newPassword: any(named: 'newPassword')),
        ).thenAnswer((_) async => const Right(null));
        when(repository.logout).thenAnswer((_) async => const Right(null));

        await notifier.updatePassword('newHunter22');

        expect(notifier.state, isA<AuthUnauthenticated>());
        verify(repository.logout).called(1);
      },
    );

    test('sets AuthError on failure without logging out', () async {
      final notifier = buildNotifier(currentUser: Right(tUser));
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        () => repository.resetPassword(newPassword: any(named: 'newPassword')),
      ).thenAnswer((_) async => const Left(ServerFailure('weak password')));

      await notifier.updatePassword('123');

      expect(notifier.state, isA<AuthError>());
      verifyNever(repository.logout);
    });
  });

  group('updateProfile', () {
    test('sets AuthAuthenticated(user) and returns Right on success', () async {
      final notifier = buildNotifier(currentUser: Right(tUser));
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      final updated = User(
        id: tUser.id,
        email: tUser.email,
        createdAt: tUser.createdAt,
        displayName: 'Alice B',
      );
      when(
        () => repository.updateProfile(
          displayName: any(named: 'displayName'),
          avatarUrl: any(named: 'avatarUrl'),
        ),
      ).thenAnswer((_) async => Right(updated));

      final result = await notifier.updateProfile(displayName: 'Alice B');

      expect(result, Right<Failure, User>(updated));
      expect(notifier.state, isA<AuthAuthenticated>());
      expect((notifier.state as AuthAuthenticated).user.displayName, 'Alice B');
    });

    test('leaves state unchanged and returns Left on failure', () async {
      final notifier = buildNotifier(currentUser: Right(tUser));
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        () => repository.updateProfile(
          displayName: any(named: 'displayName'),
          avatarUrl: any(named: 'avatarUrl'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await notifier.updateProfile(displayName: 'Alice B');

      expect(result.isLeft(), isTrue);
      expect(notifier.state, isA<AuthAuthenticated>());
      expect((notifier.state as AuthAuthenticated).user, tUser);
    });
  });

  group('deleteAccount', () {
    test('sets AuthUnauthenticated and returns Right on success', () async {
      final notifier = buildNotifier(currentUser: Right(tUser));
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        deleteAccountUseCase.call,
      ).thenAnswer((_) async => const Right(null));

      final result = await notifier.deleteAccount();

      expect(result, const Right<Failure, void>(null));
      expect(notifier.state, isA<AuthUnauthenticated>());
    });

    test('leaves state unchanged and returns Left on failure', () async {
      final notifier = buildNotifier(currentUser: Right(tUser));
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        deleteAccountUseCase.call,
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await notifier.deleteAccount();

      expect(result.isLeft(), isTrue);
      expect(notifier.state, isA<AuthAuthenticated>());
    });
  });

  group('clearError', () {
    test('moves AuthError to AuthUnauthenticated', () async {
      final notifier = buildNotifier();
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(
        () => loginUseCase(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(AuthFailure('bad credentials')));
      await notifier.login(email: 'a@b.com', password: 'wrong');
      expect(notifier.state, isA<AuthError>());

      notifier.clearError();

      expect(notifier.state, isA<AuthUnauthenticated>());
    });

    test('is a no-op when not currently in AuthError', () async {
      final notifier = buildNotifier(currentUser: Right(tUser));
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, isA<AuthAuthenticated>());

      notifier.clearError();

      expect(notifier.state, isA<AuthAuthenticated>());
    });
  });
}
