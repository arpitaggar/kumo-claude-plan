import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/create_org_cost_field_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late CreateOrgCostFieldUseCase useCase;

  const tField = OrgCostField(
    id: 'field-1',
    orgId: 'org-1',
    label: 'Department',
    fieldType: CostFieldType.select,
    separator: '-',
    sortOrder: 0,
  );

  setUpAll(() {
    registerFallbackValue(CostFieldType.select);
  });

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = CreateOrgCostFieldUseCase(mockRepo);
  });

  test('delegates to repository with the provided fields', () async {
    when(
      () => mockRepo.createCostField(
        orgId: 'org-1',
        label: 'Department',
        fieldType: CostFieldType.select,
        separator: '-',
        sourceFieldIds: const [],
      ),
    ).thenAnswer((_) async => const Right(tField));

    await useCase(
      orgId: 'org-1',
      label: 'Department',
      fieldType: CostFieldType.select,
    );

    verify(
      () => mockRepo.createCostField(
        orgId: 'org-1',
        label: 'Department',
        fieldType: CostFieldType.select,
        separator: '-',
        sourceFieldIds: const [],
      ),
    ).called(1);
  });

  test('passes sourceFieldIds through for a generated field', () async {
    when(
      () => mockRepo.createCostField(
        orgId: any(named: 'orgId'),
        label: any(named: 'label'),
        fieldType: any(named: 'fieldType'),
        separator: any(named: 'separator'),
        sourceFieldIds: any(named: 'sourceFieldIds'),
      ),
    ).thenAnswer((_) async => const Right(tField));

    await useCase(
      orgId: 'org-1',
      label: 'Cost Center',
      fieldType: CostFieldType.generated,
      sourceFieldIds: const ['field-1', 'field-2'],
    );

    verify(
      () => mockRepo.createCostField(
        orgId: 'org-1',
        label: 'Cost Center',
        fieldType: CostFieldType.generated,
        separator: '-',
        sourceFieldIds: const ['field-1', 'field-2'],
      ),
    ).called(1);
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.createCostField(
        orgId: any(named: 'orgId'),
        label: any(named: 'label'),
        fieldType: any(named: 'fieldType'),
        separator: any(named: 'separator'),
        sourceFieldIds: any(named: 'sourceFieldIds'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(
      orgId: 'org-1',
      label: 'Department',
      fieldType: CostFieldType.select,
    );

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
