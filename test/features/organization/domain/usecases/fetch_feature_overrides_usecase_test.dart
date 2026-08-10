import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_feature_override.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/fetch_feature_overrides_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late FetchFeatureOverridesUseCase useCase;

  const tOverride = OrgFeatureOverride(
    id: 'ovr-1',
    costFieldOptionId: 'opt-1',
    featureKey: 'google_maps',
    enabled: true,
  );

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = FetchFeatureOverridesUseCase(mockRepo);
  });

  test('delegates to the repository with the given optionId', () async {
    when(
      () => mockRepo.fetchFeatureOverrides('opt-1'),
    ).thenAnswer((_) async => const Right([tOverride]));

    final result = await useCase('opt-1');

    verify(() => mockRepo.fetchFeatureOverrides('opt-1')).called(1);
    result.fold(
      (_) => fail('expected Right'),
      (overrides) => expect(overrides, [tOverride]),
    );
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.fetchFeatureOverrides(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('nope')));

    final result = await useCase('opt-1');

    expect(result.isLeft(), isTrue);
  });
}
