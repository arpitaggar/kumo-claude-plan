import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_feature_override.dart';
import '../repositories/organization_repository.dart';

class FetchFeatureOverridesUseCase {
  const FetchFeatureOverridesUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, List<OrgFeatureOverride>>> call(String optionId) =>
      _repository.fetchFeatureOverrides(optionId);
}
