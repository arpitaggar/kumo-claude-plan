import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/set_cost_field_option_approval_threshold_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late SetCostFieldOptionApprovalThresholdUseCase useCase;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = SetCostFieldOptionApprovalThresholdUseCase(mockRepo);
  });

  test('delegates optionId/threshold to the repository', () async {
    when(
      () => mockRepo.setCostFieldOptionApprovalThreshold(
        optionId: 'opt-1',
        threshold: 25,
      ),
    ).thenAnswer((_) async => const Right(null));

    await useCase(optionId: 'opt-1', threshold: 25);

    verify(
      () => mockRepo.setCostFieldOptionApprovalThreshold(
        optionId: 'opt-1',
        threshold: 25,
      ),
    ).called(1);
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.setCostFieldOptionApprovalThreshold(
        optionId: any(named: 'optionId'),
        threshold: any(named: 'threshold'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('nope')));

    final result = await useCase(optionId: 'opt-1', threshold: 25);

    expect(result.isLeft(), isTrue);
  });
}
