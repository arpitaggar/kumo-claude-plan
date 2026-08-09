import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/delete_org_cost_field_option_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late DeleteOrgCostFieldOptionUseCase useCase;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = DeleteOrgCostFieldOptionUseCase(mockRepo);
  });

  test('delegates to repository with the provided id', () async {
    when(
      () => mockRepo.deleteCostFieldOption('opt-1'),
    ).thenAnswer((_) async => const Right(null));

    await useCase('opt-1');

    verify(() => mockRepo.deleteCostFieldOption('opt-1')).called(1);
  });

  test('propagates a friendly ServerFailure when the option is still in use — '
      'by a trip assignment or an active join code (stage35)', () async {
    when(() => mockRepo.deleteCostFieldOption(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure("This value is in use and can't be deleted"),
      ),
    );

    final result = await useCase('opt-1');

    result.fold(
      (f) => expect(f.message, contains('in use')),
      (_) => fail('expected Left'),
    );
  });
}
