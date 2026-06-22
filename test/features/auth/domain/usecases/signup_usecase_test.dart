import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late SignupUseCase useCase;

  final tUser = User(
    id: 'user-2',
    email: 'bob@example.com',
    createdAt: DateTime(2026, 6, 10),
    displayName: 'Bob',
  );

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = SignupUseCase(mockRepo);
  });

  group('SignupUseCase — validation', () {
    test('returns ValidationFailure for empty email', () async {
      final result =
          await useCase(email: '', password: 'password123');
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('returns ValidationFailure for empty password', () async {
      final result =
          await useCase(email: 'bob@example.com', password: '');
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('returns ValidationFailure for short password', () async {
      final result =
          await useCase(email: 'bob@example.com', password: '1234567');
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('SignupUseCase — repository delegation', () {
    test('calls repository.signUp with correct arguments', () async {
      when(() => mockRepo.signUp(
            email: 'bob@example.com',
            password: 'password123',
            displayName: 'Bob',
          )).thenAnswer((_) async => Right(tUser));

      await useCase(
          email: 'bob@example.com',
          password: 'password123',
          displayName: 'Bob');

      verify(() => mockRepo.signUp(
            email: 'bob@example.com',
            password: 'password123',
            displayName: 'Bob',
          )).called(1);
    });

    test('returns Right(user) on successful signup', () async {
      when(() => mockRepo.signUp(
            email: 'bob@example.com',
            password: 'password123',
          )).thenAnswer((_) async => Right(tUser));

      final result =
          await useCase(email: 'bob@example.com', password: 'password123');

      expect(result, Right<Failure, User>(tUser));
    });

    test('signup without displayName does not pass null displayName to repo', () async {
      when(() => mockRepo.signUp(
            email: 'bob@example.com',
            password: 'password123',
          )).thenAnswer((_) async => Right(tUser));

      await useCase(email: 'bob@example.com', password: 'password123');

      verify(() => mockRepo.signUp(
            email: 'bob@example.com',
            password: 'password123',
          )).called(1);
    });

    test('propagates AuthFailure from repository', () async {
      when(() => mockRepo.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
              (_) async => const Left(AuthFailure('Email already in use')));

      final result =
          await useCase(email: 'bob@example.com', password: 'password123');

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
