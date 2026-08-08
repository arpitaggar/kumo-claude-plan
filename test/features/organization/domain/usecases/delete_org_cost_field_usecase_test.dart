import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/delete_org_cost_field_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late DeleteOrgCostFieldUseCase useCase;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = DeleteOrgCostFieldUseCase(mockRepo);
  });

  test('delegates to repository with the provided id', () async {
    when(() => mockRepo.deleteCostField('field-1'))
        .thenAnswer((_) async => const Right(null));

    await useCase('field-1');

    verify(() => mockRepo.deleteCostField('field-1')).called(1);
  });

  test('propagates a friendly ServerFailure when the field is still in use', () async {
    when(() => mockRepo.deleteCostField(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure("This field is used by an existing trip and can't be deleted"),
      ),
    );

    final result = await useCase('field-1');

    result.fold(
      (f) => expect(f.message, contains('existing trip')),
      (_) => fail('expected Left'),
    );
  });
}
