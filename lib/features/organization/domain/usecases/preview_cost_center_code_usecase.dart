import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/organization_repository.dart';

class PreviewCostCenterCodeUseCase {
  const PreviewCostCenterCodeUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, String?>> call({
    required String orgId,
    required Map<String, String> selections,
  }) =>
      _repository.previewCostCenterCode(orgId: orgId, selections: selections);
}
