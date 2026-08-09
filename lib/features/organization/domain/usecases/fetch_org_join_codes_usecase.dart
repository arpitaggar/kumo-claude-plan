import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_join_code.dart';
import '../repositories/organization_repository.dart';

class FetchOrgJoinCodesUseCase {
  const FetchOrgJoinCodesUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, List<OrgJoinCode>>> call(String orgId) =>
      _repository.fetchJoinCodes(orgId);
}
