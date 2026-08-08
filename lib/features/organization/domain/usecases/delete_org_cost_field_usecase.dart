import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/organization_repository.dart';

class DeleteOrgCostFieldUseCase {
  const DeleteOrgCostFieldUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, void>> call(String fieldId) =>
      _repository.deleteCostField(fieldId);
}
