import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/organization_repository.dart';

class SetCostFieldOptionApprovalThresholdUseCase {
  const SetCostFieldOptionApprovalThresholdUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, void>> call({
    required String optionId,
    double? threshold,
  }) => _repository.setCostFieldOptionApprovalThreshold(
    optionId: optionId,
    threshold: threshold,
  );
}
