import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_cost_field_option.dart';
import '../repositories/organization_repository.dart';

class AddOrgCostFieldOptionUseCase {
  const AddOrgCostFieldOptionUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, OrgCostFieldOption>> call({
    required String fieldId,
    required String value,
    required String code,
  }) =>
      _repository.addCostFieldOption(fieldId: fieldId, value: value, code: code);
}
