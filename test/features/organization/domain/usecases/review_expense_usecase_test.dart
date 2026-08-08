import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/review_expense_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late ReviewExpenseUseCase useCase;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = ReviewExpenseUseCase(mockRepo);
  });

  group('approve', () {
    test('delegates to repository.approveExpense', () async {
      when(() => mockRepo.approveExpense('exp-1'))
          .thenAnswer((_) async => const Right(null));

      await useCase.approve('exp-1');

      verify(() => mockRepo.approveExpense('exp-1')).called(1);
    });

    test('propagates ServerFailure from repository', () async {
      when(() => mockRepo.approveExpense(any()))
          .thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await useCase.approve('exp-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('reject', () {
    test('delegates to repository.rejectExpense with id and reason', () async {
      when(() => mockRepo.rejectExpense('exp-1', 'Missing receipt'))
          .thenAnswer((_) async => const Right(null));

      await useCase.reject('exp-1', 'Missing receipt');

      verify(() => mockRepo.rejectExpense('exp-1', 'Missing receipt')).called(1);
    });

    test('propagates ServerFailure from repository', () async {
      when(() => mockRepo.rejectExpense(any(), any()))
          .thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await useCase.reject('exp-1', 'Missing receipt');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
