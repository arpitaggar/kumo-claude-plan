import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late LoginUseCase useCase;

  final tUser = User(
    id: 'user-1',
    email: 'alice@example.com',
    createdAt: DateTime(2026, 6, 10),
    emailVerified: true,
  );

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = LoginUseCase(mockRepo);
  });

  group('LoginUseCase — validation', () {
    test('returns ValidationFailure for empty email', () async {
      final result = await useCase(email: '', password: 'password123');
      expect(result, isA<Left<Failure, User>>());
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
      verifyNever(() => mockRepo.login(email: any(named: 'email'), password: any(named: 'password')));
    });

    test('returns ValidationFailure for empty password', () async {
      final result = await useCase(email: 'alice@example.com', password: '');
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
      verifyNever(() => mockRepo.login(email: any(named: 'email'), password: any(named: 'password')));
    });

    test('returns ValidationFailure for password shorter than 8 chars', () async {
      final result =
          await useCase(email: 'alice@example.com', password: 'short');
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('LoginUseCase — repository delegation', () {
    test('calls repository.login with valid credentials', () async {
      when(() => mockRepo.login(
            email: 'alice@example.com',
            password: 'password123',
          )).thenAnswer((_) async => Right(tUser));

      await useCase(email: 'alice@example.com', password: 'password123');

      verify(() => mockRepo.login(
            email: 'alice@example.com',
            password: 'password123',
          )).called(1);
    });

    test('returns Right(user) on successful login', () async {
      when(() => mockRepo.login(
            email: 'alice@example.com',
            password: 'password123',
          )).thenAnswer((_) async => Right(tUser));

      final result =
          await useCase(email: 'alice@example.com', password: 'password123');

      expect(result, Right<Failure, User>(tUser));
    });

    test('propagates AuthFailure from repository', () async {
      when(() => mockRepo.login(
            email: 'alice@example.com',
            password: 'password123',
          )).thenAnswer(
              (_) async => Left(AuthFailure.invalidCredentials()));

      final result =
          await useCase(email: 'alice@example.com', password: 'password123');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('propagates NetworkFailure from repository', () async {
      when(() => mockRepo.login(
            email: 'alice@example.com',
            password: 'password123',
          )).thenAnswer(
              (_) async => Left(NetworkFailure.noInternet()));

      final result =
          await useCase(email: 'alice@example.com', password: 'password123');

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
