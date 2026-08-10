import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/organization_repository.dart';

class SetOrgDefaultApprovalThresholdUseCase {
  const SetOrgDefaultApprovalThresholdUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, void>> call({
    required String orgId,
    double? threshold,
  }) => _repository.setOrgDefaultApprovalThreshold(
    orgId: orgId,
    threshold: threshold,
  );
}
