import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late LogoutUseCase useCase;

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = LogoutUseCase(mockRepo);
  });

  test('delegates to repository', () async {
    when(() => mockRepo.logout()).thenAnswer((_) async => const Right(null));

    final result = await useCase();

    verify(() => mockRepo.logout()).called(1);
    expect(result, const Right<Failure, void>(null));
  });

  test('propagates AuthFailure from repository', () async {
    when(
      () => mockRepo.logout(),
    ).thenAnswer((_) async => const Left(AuthFailure('session expired')));

    final result = await useCase();

    result.fold(
      (f) => expect(f, isA<AuthFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
