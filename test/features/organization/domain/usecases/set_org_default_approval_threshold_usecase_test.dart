import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/set_org_default_approval_threshold_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late SetOrgDefaultApprovalThresholdUseCase useCase;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = SetOrgDefaultApprovalThresholdUseCase(mockRepo);
  });

  test('delegates orgId/threshold to the repository', () async {
    when(
      () => mockRepo.setOrgDefaultApprovalThreshold(
        orgId: 'org-1',
        threshold: 100,
      ),
    ).thenAnswer((_) async => const Right(null));

    await useCase(orgId: 'org-1', threshold: 100);

    verify(
      () => mockRepo.setOrgDefaultApprovalThreshold(
        orgId: 'org-1',
        threshold: 100,
      ),
    ).called(1);
  });

  test('passes a null threshold through to clear it', () async {
    when(
      () => mockRepo.setOrgDefaultApprovalThreshold(
        orgId: 'org-1',
        threshold: null,
      ),
    ).thenAnswer((_) async => const Right(null));

    await useCase(orgId: 'org-1');

    verify(
      () => mockRepo.setOrgDefaultApprovalThreshold(
        orgId: 'org-1',
        threshold: null,
      ),
    ).called(1);
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.setOrgDefaultApprovalThreshold(
        orgId: any(named: 'orgId'),
        threshold: any(named: 'threshold'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('nope')));

    final result = await useCase(orgId: 'org-1', threshold: 50);

    expect(result.isLeft(), isTrue);
  });
}
