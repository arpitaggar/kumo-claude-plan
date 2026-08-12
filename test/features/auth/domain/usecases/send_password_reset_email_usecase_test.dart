import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/send_password_reset_email_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late SendPasswordResetEmailUseCase useCase;

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = SendPasswordResetEmailUseCase(mockRepo);
  });

  test('delegates to repository with the given email', () async {
    when(
      () => mockRepo.sendPasswordResetEmail('alice@example.com'),
    ).thenAnswer((_) async => const Right(null));

    await useCase('alice@example.com');

    verify(
      () => mockRepo.sendPasswordResetEmail('alice@example.com'),
    ).called(1);
  });

  test('returns Right(null) on success', () async {
    when(
      () => mockRepo.sendPasswordResetEmail(any()),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase('alice@example.com');

    expect(result, const Right<Failure, void>(null));
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.sendPasswordResetEmail(any()),
    ).thenAnswer((_) async => const Left(NotFoundFailure('No account found')));

    final result = await useCase('alice@example.com');

    result.fold(
      (f) => expect(f, isA<NotFoundFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
