import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/preview_cost_center_code_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late PreviewCostCenterCodeUseCase useCase;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = PreviewCostCenterCodeUseCase(mockRepo);
  });

  test('delegates to repository with orgId and selections', () async {
    when(
      () => mockRepo.previewCostCenterCode(
        orgId: 'org-1',
        selections: {'field-1': 'opt-1'},
      ),
    ).thenAnswer((_) async => const Right('SAL-FAL'));

    final result = await useCase(
      orgId: 'org-1',
      selections: {'field-1': 'opt-1'},
    );

    verify(
      () => mockRepo.previewCostCenterCode(
        orgId: 'org-1',
        selections: {'field-1': 'opt-1'},
      ),
    ).called(1);
    expect(result, const Right<Failure, String?>('SAL-FAL'));
  });

  test('returns Right(null) for an incomplete selection', () async {
    when(
      () => mockRepo.previewCostCenterCode(
        orgId: any(named: 'orgId'),
        selections: any(named: 'selections'),
      ),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase(orgId: 'org-1', selections: const {});

    result.fold((_) => fail('expected Right'), (code) => expect(code, isNull));
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.previewCostCenterCode(
        orgId: any(named: 'orgId'),
        selections: any(named: 'selections'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(orgId: 'org-1', selections: const {});

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
