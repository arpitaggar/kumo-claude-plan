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

  // A fixed adult DOB, computed relative to "now" so this test suite never
  // starts failing on its own as calendar time passes.
  final tAdultDob = DateTime.now().subtract(const Duration(days: 365 * 30));

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = SignupUseCase(mockRepo);
    registerFallbackValue(tAdultDob);
  });

  group('SignupUseCase — validation', () {
    test('returns ValidationFailure for empty email', () async {
      final result = await useCase(
        email: '',
        password: 'password123',
        dateOfBirth: tAdultDob,
      );
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('returns ValidationFailure for empty password', () async {
      final result = await useCase(
        email: 'bob@example.com',
        password: '',
        dateOfBirth: tAdultDob,
      );
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('returns ValidationFailure for short password', () async {
      final result = await useCase(
        email: 'bob@example.com',
        password: '1234567',
        dateOfBirth: tAdultDob,
      );
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('SignupUseCase — age gate (Captain/Crew must be 18+)', () {
    test('rejects signup with a DOB implying under 18, without ever calling '
        'the repository', () async {
      final under18Dob = DateTime.now().subtract(
        const Duration(days: 365 * 17),
      );

      final result = await useCase(
        email: 'minor@example.com',
        password: 'password123',
        dateOfBirth: under18Dob,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail(
          'expected Left — an under-18 signup must never reach the repository',
        ),
      );
      verifyNever(
        () => mockRepo.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          dateOfBirth: any(named: 'dateOfBirth'),
        ),
      );
    });

    test('rejects a DOB exactly one day short of the 18th birthday', () async {
      final now = DateTime.now();
      final almostEighteen = DateTime(now.year - 18, now.month, now.day + 1);

      final result = await useCase(
        email: 'minor@example.com',
        password: 'password123',
        dateOfBirth: almostEighteen,
      );

      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left — one day short of 18 is still under 18'),
      );
    });

    test('accepts a DOB exactly on the 18th birthday', () async {
      final now = DateTime.now();
      final exactlyEighteen = DateTime(now.year - 18, now.month, now.day);
      when(
        () => mockRepo.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          dateOfBirth: any(named: 'dateOfBirth'),
        ),
      ).thenAnswer((_) async => Right(tUser));

      final result = await useCase(
        email: 'bob@example.com',
        password: 'password123',
        dateOfBirth: exactlyEighteen,
      );

      expect(result.isRight(), isTrue);
    });

    test('rejects a future date of birth', () async {
      final futureDob = DateTime.now().add(const Duration(days: 1));

      final result = await useCase(
        email: 'bob@example.com',
        password: 'password123',
        dateOfBirth: futureDob,
      );

      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('SignupUseCase — repository delegation', () {
    test('calls repository.signUp with correct arguments', () async {
      when(
        () => mockRepo.signUp(
          email: 'bob@example.com',
          password: 'password123',
          dateOfBirth: tAdultDob,
          displayName: 'Bob',
        ),
      ).thenAnswer((_) async => Right(tUser));

      await useCase(
        email: 'bob@example.com',
        password: 'password123',
        dateOfBirth: tAdultDob,
        displayName: 'Bob',
      );

      verify(
        () => mockRepo.signUp(
          email: 'bob@example.com',
          password: 'password123',
          dateOfBirth: tAdultDob,
          displayName: 'Bob',
        ),
      ).called(1);
    });

    test('returns Right(user) on successful signup', () async {
      when(
        () => mockRepo.signUp(
          email: 'bob@example.com',
          password: 'password123',
          dateOfBirth: tAdultDob,
        ),
      ).thenAnswer((_) async => Right(tUser));

      final result = await useCase(
        email: 'bob@example.com',
        password: 'password123',
        dateOfBirth: tAdultDob,
      );

      expect(result, Right<Failure, User>(tUser));
    });

    test(
      'signup without displayName does not pass null displayName to repo',
      () async {
        when(
          () => mockRepo.signUp(
            email: 'bob@example.com',
            password: 'password123',
            dateOfBirth: tAdultDob,
          ),
        ).thenAnswer((_) async => Right(tUser));

        await useCase(
          email: 'bob@example.com',
          password: 'password123',
          dateOfBirth: tAdultDob,
        );

        verify(
          () => mockRepo.signUp(
            email: 'bob@example.com',
            password: 'password123',
            dateOfBirth: tAdultDob,
          ),
        ).called(1);
      },
    );

    test('propagates AuthFailure from repository', () async {
      when(
        () => mockRepo.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          dateOfBirth: any(named: 'dateOfBirth'),
        ),
      ).thenAnswer(
        (_) async => const Left(AuthFailure('Email already in use')),
      );

      final result = await useCase(
        email: 'bob@example.com',
        password: 'password123',
        dateOfBirth: tAdultDob,
      );

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
