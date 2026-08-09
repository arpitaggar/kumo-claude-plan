import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field_option.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/add_org_cost_field_option_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late AddOrgCostFieldOptionUseCase useCase;

  const tOption = OrgCostFieldOption(
    id: 'opt-1',
    fieldId: 'field-1',
    value: 'Sales',
    code: 'SAL',
    sortOrder: 0,
  );

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = AddOrgCostFieldOptionUseCase(mockRepo);
  });

  test('delegates to repository with fieldId, value and code', () async {
    when(
      () => mockRepo.addCostFieldOption(
        fieldId: 'field-1',
        value: 'Sales',
        code: 'SAL',
      ),
    ).thenAnswer((_) async => const Right(tOption));

    await useCase(fieldId: 'field-1', value: 'Sales', code: 'SAL');

    verify(
      () => mockRepo.addCostFieldOption(
        fieldId: 'field-1',
        value: 'Sales',
        code: 'SAL',
      ),
    ).called(1);
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.addCostFieldOption(
        fieldId: any(named: 'fieldId'),
        value: any(named: 'value'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(
      fieldId: 'field-1',
      value: 'Sales',
      code: 'SAL',
    );

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
