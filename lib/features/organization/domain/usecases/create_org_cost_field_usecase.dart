import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_cost_field.dart';
import '../repositories/organization_repository.dart';

class CreateOrgCostFieldUseCase {
  const CreateOrgCostFieldUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, OrgCostField>> call({
    required String orgId,
    required String label,
    required CostFieldType fieldType,
    String separator = '-',
    List<String> sourceFieldIds = const [],
  }) =>
      _repository.createCostField(
        orgId: orgId,
        label: label,
        fieldType: fieldType,
        separator: separator,
        sourceFieldIds: sourceFieldIds,
      );
}
