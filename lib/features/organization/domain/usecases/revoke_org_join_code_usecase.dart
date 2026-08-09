import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/organization_repository.dart';

class RevokeOrgJoinCodeUseCase {
  const RevokeOrgJoinCodeUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, void>> call(String codeId) =>
      _repository.revokeJoinCode(codeId);
}
