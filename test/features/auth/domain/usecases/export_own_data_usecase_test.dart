import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/export_own_data_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late ExportOwnDataUseCase useCase;

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = ExportOwnDataUseCase(mockRepo);
  });

  group('ExportOwnDataUseCase', () {
    test('calls repository.exportOwnData exactly once', () async {
      when(
        () => mockRepo.exportOwnData(),
      ).thenAnswer((_) async => const Right(<String, dynamic>{}));

      await useCase();

      verify(() => mockRepo.exportOwnData()).called(1);
    });

    test('returns Right(data) when repository succeeds', () async {
      final data = <String, dynamic>{
        'profile': {'id': 'u1'},
        'itineraries': <dynamic>[],
      };
      when(() => mockRepo.exportOwnData()).thenAnswer((_) async => Right(data));

      final result = await useCase();

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected Right'), (d) => expect(d, data));
    });

    test('propagates AuthFailure from repository', () async {
      when(
        () => mockRepo.exportOwnData(),
      ).thenAnswer((_) async => const Left(AuthFailure('session expired')));

      final result = await useCase();

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('propagates UnexpectedFailure from repository', () async {
      when(
        () => mockRepo.exportOwnData(),
      ).thenAnswer((_) async => const Left(UnexpectedFailure('RPC error')));

      final result = await useCase();

      result.fold((f) {
        expect(f, isA<UnexpectedFailure>());
        expect(f.message, 'RPC error');
      }, (_) => fail('expected Left'));
    });

    test('does not call any other repository method', () async {
      when(
        () => mockRepo.exportOwnData(),
      ).thenAnswer((_) async => const Right(<String, dynamic>{}));

      await useCase();

      verifyNever(() => mockRepo.deleteAccount());
      verifyNever(
        () => mockRepo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });
  });
}
