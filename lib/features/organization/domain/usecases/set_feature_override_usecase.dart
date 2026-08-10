import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/organization_repository.dart';

class SetFeatureOverrideUseCase {
  const SetFeatureOverrideUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, void>> call({
    required String optionId,
    required String featureKey,
    required bool enabled,
  }) => _repository.setFeatureOverride(
    optionId: optionId,
    featureKey: featureKey,
    enabled: enabled,
  );
}
