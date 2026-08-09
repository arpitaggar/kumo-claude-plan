import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/organization.dart';
import '../repositories/organization_repository.dart';

class RedeemOrgJoinCodeUseCase {
  const RedeemOrgJoinCodeUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, Organization>> call(String code) =>
      _repository.redeemJoinCode(code);
}
