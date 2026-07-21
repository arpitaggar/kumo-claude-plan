import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late DeleteAccountUseCase useCase;

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = DeleteAccountUseCase(mockRepo);
  });

  group('DeleteAccountUseCase', () {
    test('calls repository.deleteAccount exactly once', () async {
      when(() => mockRepo.deleteAccount())
          .thenAnswer((_) async => const Right(null));

      await useCase();

      verify(() => mockRepo.deleteAccount()).called(1);
    });

    test('returns Right(null) when repository succeeds', () async {
      when(() => mockRepo.deleteAccount())
          .thenAnswer((_) async => const Right(null));

      final result = await useCase();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (_) {},
      );
    });

    test('propagates AuthFailure from repository', () async {
      when(() => mockRepo.deleteAccount()).thenAnswer(
        (_) async => const Left(AuthFailure('session expired')),
      );

      final result = await useCase();

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('propagates UnexpectedFailure from repository', () async {
      when(() => mockRepo.deleteAccount()).thenAnswer(
        (_) async => const Left(UnexpectedFailure('RPC error')),
      );

      final result = await useCase();

      result.fold(
        (f) {
          expect(f, isA<UnexpectedFailure>());
          expect(f.message, 'RPC error');
        },
        (_) => fail('expected Left'),
      );
    });

    test('does not call any other repository method', () async {
      when(() => mockRepo.deleteAccount())
          .thenAnswer((_) async => const Right(null));

      await useCase();

      verifyNever(() => mockRepo.logout());
      verifyNever(
        () => mockRepo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });
  });
}
