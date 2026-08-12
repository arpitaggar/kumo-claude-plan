import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/confirm_age_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late ConfirmAgeUseCase useCase;

  final tDob = DateTime(1990, 1, 1);

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = ConfirmAgeUseCase(mockRepo);
  });

  test('delegates to repository.confirmAge with the given date', () async {
    when(
      () => mockRepo.confirmAge(tDob),
    ).thenAnswer((_) async => const Right(true));

    await useCase(tDob);

    verify(() => mockRepo.confirmAge(tDob)).called(1);
  });

  test('returns Right(true) when verified', () async {
    when(
      () => mockRepo.confirmAge(any()),
    ).thenAnswer((_) async => const Right(true));

    final result = await useCase(tDob);

    result.fold(
      (_) => fail('expected Right'),
      (verified) => expect(verified, isTrue),
    );
  });

  test('returns Right(false) when rejected as underage', () async {
    when(
      () => mockRepo.confirmAge(any()),
    ).thenAnswer((_) async => const Right(false));

    final result = await useCase(tDob);

    result.fold(
      (_) => fail('expected Right'),
      (verified) => expect(verified, isFalse),
    );
  });

  test('propagates a Failure from the repository', () async {
    when(
      () => mockRepo.confirmAge(any()),
    ).thenAnswer((_) async => const Left(AuthFailure('Not authenticated')));

    final result = await useCase(tDob);

    result.fold(
      (f) => expect(f, isA<AuthFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
