import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/pending_expense_approval.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/fetch_pending_expense_approvals_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late FetchPendingExpenseApprovalsUseCase useCase;

  final tApproval = PendingExpenseApproval(
    expenseId: 'expense-1',
    itineraryId: 'it-1',
    tripTitle: 'Chiang Mai Trip',
    payerId: 'user-1',
    payerName: 'Alice',
    title: 'Dinner',
    amount: 90,
    currencyCode: 'USD',
    category: 'food',
    submittedAt: DateTime.utc(2026, 6),
  );

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = FetchPendingExpenseApprovalsUseCase(mockRepo);
  });

  test('delegates to repository with the given orgId', () async {
    when(
      () => mockRepo.fetchPendingApprovals('org-1'),
    ).thenAnswer((_) async => Right([tApproval]));

    final result = await useCase('org-1');

    verify(() => mockRepo.fetchPendingApprovals('org-1')).called(1);
    result.fold(
      (_) => fail('expected Right'),
      (approvals) => expect(approvals, [tApproval]),
    );
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.fetchPendingApprovals(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('org-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
