import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_cost_field.dart';
import '../repositories/organization_repository.dart';

class FetchOrgCostFieldsUseCase {
  const FetchOrgCostFieldsUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, List<OrgCostField>>> call(String orgId) =>
      _repository.fetchOrgCostFields(orgId);
}
