import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/fetch_org_cost_fields_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late FetchOrgCostFieldsUseCase useCase;

  const tField = OrgCostField(
    id: 'field-1',
    orgId: 'org-1',
    label: 'Department',
    fieldType: CostFieldType.select,
    separator: '-',
    sortOrder: 0,
  );

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = FetchOrgCostFieldsUseCase(mockRepo);
  });

  test('delegates to repository with the given orgId', () async {
    when(
      () => mockRepo.fetchOrgCostFields('org-1'),
    ).thenAnswer((_) async => const Right([tField]));

    final result = await useCase('org-1');

    verify(() => mockRepo.fetchOrgCostFields('org-1')).called(1);
    result.fold(
      (_) => fail('expected Right'),
      (fields) => expect(fields, const [tField]),
    );
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.fetchOrgCostFields(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('org-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
