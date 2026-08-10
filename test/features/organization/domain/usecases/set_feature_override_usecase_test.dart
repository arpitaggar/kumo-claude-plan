import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/set_feature_override_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late SetFeatureOverrideUseCase useCase;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = SetFeatureOverrideUseCase(mockRepo);
  });

  test('delegates optionId/featureKey/enabled to the repository', () async {
    when(
      () => mockRepo.setFeatureOverride(
        optionId: 'opt-1',
        featureKey: 'google_maps',
        enabled: true,
      ),
    ).thenAnswer((_) async => const Right(null));

    await useCase(optionId: 'opt-1', featureKey: 'google_maps', enabled: true);

    verify(
      () => mockRepo.setFeatureOverride(
        optionId: 'opt-1',
        featureKey: 'google_maps',
        enabled: true,
      ),
    ).called(1);
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.setFeatureOverride(
        optionId: any(named: 'optionId'),
        featureKey: any(named: 'featureKey'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('nope')));

    final result = await useCase(
      optionId: 'opt-1',
      featureKey: 'google_maps',
      enabled: false,
    );

    expect(result.isLeft(), isTrue);
  });
}
